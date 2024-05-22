# Utiliser l'image de base WordPress 6.2 avec Apache
FROM wordpress:6.3-apache

# When your application needs to interact with UTF-8.
ENV LANG C.UTF-8

# Installer le client MySQL et phpMyAdmin
USER root

# Mettre à jour les paquets, installer les dépendances nécessaires, télécharger et configurer phpMyAdmin en une seule commande RUN pour minimiser les couches d'image
RUN sed -i -e 's/^APT/# APT/' -e 's/^DPkg/# DPkg/' /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends default-mysql-client wget unzip && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /usr/share/phpmyadmin && \
    wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz -O /tmp/phpMyAdmin-latest-all-languages.tar.gz && \
    tar xzf /tmp/phpMyAdmin-latest-all-languages.tar.gz --strip-components=1 -C /usr/share/phpmyadmin && \
    rm -f /tmp/phpMyAdmin-latest-all-languages.tar.gz && \
    ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin && \
    chown -R www-data:www-data /usr/share/phpmyadmin

# Créer un fichier de test et un répertoire de test
RUN touch /root/test-$(date +"%d-%m-%Y").txt && \
    mkdir /root/testrep2

COPY init-db.sh /usr/local/bin/init-db.sh
RUN chmod +x /usr/local/bin/init-db.sh
    
COPY custom-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["apache2-foreground"]
