import os
import re


for root, dirs, files in os.walk("."):
    for file in files:
        filename = os.path.join(root, file)
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()
                if re.search("indicatic-e1", content):
                    print(f"Replace 'indicatic-e1' with 'indicatice2' in {filename}")
                    # new_content = re.sub("indicatic-e1", "indicatice2", content)
                    # with open(filename, 'w', encoding='utf-8') as f:
                    #     f.write(new_content)
        except (UnicodeDecodeError, PermissionError, IsADirectoryError):
            # Saltar archivos binarios o sin permisos
            continue