#!/bin/bash

# Chemin du répertoire contenant les fichiers .sh
REPERTOIRE="/home/alex/Projet/codeNAS"

# Vérification si le répertoire existe
if [ -d "$REPERTOIRE" ]; then
    echo "Conversion des fichiers .sh dans le répertoire : $REPERTOIRE"
    # Parcours et conversion des fichiers .sh avec dos2unix
    find "$REPERTOIRE" -type f -name "*.sh" -exec dos2unix {} +
    echo "Conversion terminée !"
else
    echo "Le répertoire spécifié n'existe pas : $REPERTOIRE"
    exit 1
fi
