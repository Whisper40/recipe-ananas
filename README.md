# Recettes Ananas

Application Flutter de gestion de recettes, en français, conçue pour Android 15 et supérieur.

## Fonctionnalités

- Création, lecture, modification et suppression de recettes.
- Titre obligatoire, photo facultative, ingrédients, description/préparation et note de 0 à 5 étoiles.
- Affichage de la photo dans la liste des recettes.
- Nom Android : **Recettes Ananas**, avec une icône photo d’ananas.
- Recherche insensible à la casse sur le titre.
- Tri alphabétique automatique.
- Catégories personnalisées, sélection multiple sur une recette et filtre par catégorie.
- Ouverture des recettes en lecture seule, avec bouton d’édition explicite.
- Affichage complet des ingrédients et de la préparation, sans texte tronqué.
- Sauvegarde locale persistante sur le téléphone.
- Export JSON manuel avec nom daté (`recettes_YYYYMMDD_HHmmss.json`) via le sélecteur Android, y compris vers Nextcloud.
- Restauration d’un backup Recettes Ananas, d’un tableau `recipes_0.json` ou d’une archive `.rtk` MyRecipeBox, avec confirmation avant remplacement des données actuelles.
- Affichage de la version déployée et vérification automatique des releases GitHub, avec téléchargement puis lancement de l’installation de l’APK.
- Icône de l’application : [Pineapple](https://www.flaticon.com/free-icon/pineapple_5582711), créée par [andinur](https://www.flaticon.com/authors/andinur) (attribution Flaticon requise).

## Migrer une sauvegarde MyRecipeBox

La migration de `myrecipebox_rtk_2026-05-23.rtk` est directe :

1. Installer l’APK Recettes Ananas sur le téléphone.
2. Ouvrir le menu de sauvegarde en haut à droite.
3. Choisir **Restaurer une sauvegarde**.
4. Sélectionner le fichier `.rtk` MyRecipeBox, depuis le stockage local ou Nextcloud.
5. Vérifier le nombre de recettes puis confirmer **Restaurer**.

La restauration remplace les recettes actuellement présentes dans Recettes Ananas. Le fichier `.rtk` est lu comme une archive ZIP : les champs sont convertis ainsi :

- `title` → titre ;
- `ingredients` et `quantity` → ingrédients ;
- `description`, `instructions`, `preparation`, `steps`, `notes`, les temps, les ustensiles, la nutrition et les liens → description et préparation concaténées avec un libellé ;
- `rating` → note sur 5 ;
- `categories.json` et `categories` sur chaque recette → catégories importées et associées à la recette ;
- `pictures` et les fichiers PNG/JPG de l’archive → photo de la recette.

Les champs supplémentaires sont conservés dans la description sous forme de sections libellées. Ils ne deviennent pas des champs séparés dans Recettes Ananas, mais leur contenu n’est plus perdu pendant la migration.

## Développement

Le projet utilise Flutter 3.44 et Dart 3.12. Les dépendances sont installées avec :

```bash
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
flutter pub get
```

## Générer l’APK

Le script `build_apk.sh` désactive le proxy uniquement pour les commandes Flutter, vérifie l’analyse statique puis génère un APK release dans `dist/` :

```bash
./build_apk.sh
```

Les APK release doivent toujours être signés avec le même keystore. La CI
utilise les secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS` et
`KEY_PASSWORD` ; le keystore ne doit jamais être régénéré ou remplacé. Le
package Android reste `com.recettebox.recette_box` et le `versionCode` doit
augmenter à chaque publication. Sans cette continuité de signature, Android
refuse une mise à jour avec un message de conflit de package ; une ancienne
installation signée avec une clé différente doit alors être désinstallée une
fois.

Le script détecte automatiquement le SDK Android installé par Homebrew dans `/opt/homebrew/share/android-commandlinetools` ainsi que Java 17. Pour un autre emplacement, définir `ANDROID_HOME` et `JAVA_HOME` avant son exécution.

## Format de sauvegarde

Le JSON exporté contient une enveloppe versionnée :

```json
{
  "format": "recette_box_backup",
  "version": 1,
  "exportedAt": "2026-08-05T12:00:00.000Z",
  "recipes": [
    {
      "title": "Tarte aux pommes",
      "ingredients": "Pommes\nPâte brisée",
      "description": "Cuire 35 minutes.",
      "rating": 4,
      "categories": ["Dessert"],
      "imageBase64": "..."
    }
  ],
  "categories": ["Dessert"]
}
```

Les champs propres à MyRecipeBox sont convertis vers `title`, `ingredients`, `description`, `rating` et `imageBase64`. Les autres contenus sont concaténés dans les ingrédients ou la description lors de l’import RTK.

## Crédits de l’icône

La photo d’ananas utilisée pour l’icône provient de [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Pineapple.jpg), photographiée par Renee Comet pour le National Cancer Institute. Elle est indiquée comme appartenant au domaine public.
