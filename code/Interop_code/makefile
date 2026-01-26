# Nom de l'exécutable
EXEC = my_program

# Les fichiers sources
SRCS = main.c alpy.c

# Les fichiers objets générés
OBJS = $(SRCS:.c=.o)

# Les en-têtes
HEADERS = alpy.h

# Les options de compilation
CFLAGS = -Wall -Wextra -Werror -std=c99

# La règle par défaut
all: $(EXEC)

# Règle pour créer l'exécutable
$(EXEC): $(OBJS)
	$(CC) -o $@ $^

# Règle pour créer les fichiers objets
%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

# Nettoyage des fichiers objets et de l'exécutable
clean:
	rm -f $(OBJS) $(EXEC)

# Indiquer à make que les cibles ne sont pas des fichiers
.PHONY: all clean

