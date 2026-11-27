# Sécurité

## Les secrets et où ils vivent

| Secret | Où il est stocké | Comment il circule |
|---|---|---|
| Secret applicatif de dev | Parameter Store, `/novasphere/dev/app_secret` (SecureString, clé `aws/ssm`) | Secret GitHub `APP_SECRET_DEV` → `TF_VAR_app_secret` → écrit par Terraform en `value_wo` |
| Secret applicatif de prod | Parameter Store, `/novasphere/prod/app_secret` (SecureString, clé `aws/ssm`) | Secret GitHub `APP_SECRET_PROD` → `TF_VAR_app_secret` → écrit par Terraform en `value_wo` |
| Identifiants de session du Learner Lab | Secrets GitHub `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | Recopiés à chaque Start Lab par `scripts/ci-secrets.sh`, via l'entrée standard (jamais en argument de commande) |

Le secret applicatif :
- est déclaré `ephemeral` et `sensitive` dans Terraform : il n'a pas de valeur par défaut et n'est jamais écrit dans un fichier ;
- est écrit en **écriture seule** (`value_wo`) : le state ne contient que `has_value_wo: true` et le numéro de version, jamais la valeur. Pour le changer, on incrémente `app_secret_version` ;
- est lu par l'instance au démarrage grâce à son profil IAM. Le script reçoit seulement le **chemin** du secret de son environnement par `templatefile` ;
- n'est jamais affiché : la page indique « secret chargé : oui » avec une empreinte SHA-256 tronquée à 8 caractères, puis la variable est effacée (`unset`).

Chaque environnement a son propre secret, dont le chemin est construit à partir de `var.environment` : la prod ne peut pas lire le secret de dev.

## Vérifications : aucun secret nulle part

| Endroit | Vérification | Résultat |
|---|---|---|
| State | `terraform state pull \| grep -A12 aws_ssm_parameter` | Seulement `has_value_wo: true`, aucune valeur |
| Historique Git du projet | `gitleaks git` sur 8 commits | `no leaks found` |
| Historique Git du module | `gitleaks git` sur 5 commits | `no leaks found` |
| Fichiers versionnés | `git ls-files \| grep -E 'tfstate\|tfvars$\|tfplan\|pem\|env'` | Aucun fichier sensible |
| Logs de CI | Lecture des runs GitHub Actions | Identifiants et secret masqués en `***` |
| Script de démarrage | Lecture de `bootstrap.sh` | Aucun secret, seulement le chemin du paramètre |

Le `.gitignore` exclut `.terraform/`, `*.tfstate*`, `*.tfvars` (sauf les `.example`), `*.tfplan`, `*.pem` et `.env`.

## Politique IAM idéale de l'instance

Le Learner Lab impose `LabInstanceProfile`, beaucoup trop large. Dans un compte classique, l'instance aurait un rôle limité à la lecture du secret de **son** environnement :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LireSonSecret",
      "Effect": "Allow",
      "Action": "ssm:GetParameter",
      "Resource": "arn:aws:ssm:us-east-1:<compte>:parameter/novasphere/<environnement>/*"
    },
    {
      "Sid": "DechiffrerViaSsmUniquement",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "arn:aws:kms:us-east-1:<compte>:alias/aws/ssm",
      "Condition": {
        "StringEquals": { "kms:ViaService": "ssm.us-east-1.amazonaws.com" }
      }
    }
  ]
}
```

complétée par la politique gérée `AmazonSSMManagedInstanceCore` pour l'administration par Session Manager, sans SSH.

## Identifiants du lab et fédération OIDC

| | Identifiants du lab (utilisé ici) | Fédération OIDC (compte classique) |
|---|---|---|
| Ce que GitHub stocke | Trois identifiants de session en secrets | Rien, seulement l'ARN d'un rôle |
| Durée de vie | 4 heures, à recopier à chaque Start Lab | Jeton de quelques minutes, émis à chaque run |
| Périmètre | Tous les droits du rôle `voclabs` | Un rôle dédié, limité par une politique de confiance (dépôt, branche, environnement) |
| Risque en cas de fuite | Utilisables par n'importe qui jusqu'à expiration | Rien à voler : le jeton n'est accepté que pour ce dépôt |

Le lab refuse la création d'un fournisseur OIDC. La configuration est écrite à titre documentaire dans `envs/dev/ci_oidc_compte_classique.tf.exemple`, non appliquée.

## Durcissement en place

- IMDSv2 obligatoire (`http_tokens = "required"`), limite de saut à 1.
- Disques EBS chiffrés.
- Aucun port SSH ni paire de clés ; Security Group des instances qui n'accepte que l'ALB, en règles en ligne pour que toute règle ajoutée à la main soit détectée comme une dérive.
- Sortie des instances limitée à HTTPS (dépôts de paquets et Parameter Store), vérifiée en remplaçant une instance.
- En-têtes HTTP invalides rejetés par l'ALB (`drop_invalid_header_fields`).
- Security Group par défaut des VPC sans aucune règle.
- Bucket de state versionné, chiffré, accès public bloqué, verrou natif (`use_lockfile`).

## Résultats du scan checkov

Le scan tourne dans la CI sur chaque pull request (projet et module, modules externes compris) et **bloque** la PR en cas d'alerte non traitée. Premier passage : 115 contrôles réussis, 21 alertes. État actuel : 112 réussis, 0 en échec, alertes conservées justifiées ci-dessous.

### Alertes corrigées

| Contrôle | Correction |
|---|---|
| CKV_AWS_23 : règles sans description | Descriptions ajoutées (module v1.3.0) |
| CKV_AWS_382 : sortie totale des instances | Sortie limitée à TCP 443 (module v1.3.0) |
| CKV_AWS_394 : zones de disponibilité non figées | Zones fixées à `us-east-1a` et `us-east-1b` |
| CKV2_AWS_12 : SG par défaut du VPC | Règles vides déclarées explicitement ; voir faux positif ci-dessous |

### Alertes conservées

| Contrôle | Raison |
|---|---|
| CKV_AWS_260 : port 80 ouvert à Internet sur l'ALB | Site public : l'ALB doit être joignable. Les instances, elles, n'acceptent que l'ALB |
| CKV_AWS_2, CKV_AWS_103, CKV_AWS_378, CKV2_AWS_20 : pas de HTTPS | Pas de domaine dans le lab ; HTTPS fait partie des extensions possibles |
| CKV_AWS_150 : pas de protection contre la suppression de l'ALB | L'infrastructure est détruite à chaque fin de session |
| CKV_AWS_91 : pas de logs d'accès ALB | Exige un bucket créé par Terraform, interdit dans le lab |
| CKV2_AWS_28 : pas de WAF | Coût, hors périmètre du socle |
| CKV_AWS_130 : IP publiques sur les subnets | Imposé par le socle : pas de NAT Gateway. Ignoré globalement car la ressource est dans le module du registre |
| CKV_AWS_337 : pas de clé KMS dédiée pour le secret | Clé gérée par AWS `aws/ssm` ; une CMK serait l'étape suivante en production |
| CKV_TF_1 : modules non référencés par hash de commit | Le cahier des charges impose un tag `vX.Y.Z`, jamais modifié après publication |

### Faux positif

CKV2_AWS_12 reste signalé parce que checkov ne relie pas le VPC à son Security Group par défaut quand les deux sont créés dans le module du registre. Vérification sur AWS dans les deux VPC : 0 règle d'entrée, 0 règle de sortie. L'alerte est ignorée dans la configuration du scan.
