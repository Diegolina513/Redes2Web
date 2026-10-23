# Redes2Web

Practica de CI/CD: Flask, GitHub Actions, Docker Hub y AWS EC2.

## Flujo

1. Un push a main dispara GitHub Actions.
2. El workflow ejecuta pruebas, construye la imagen y verifica su respuesta HTTP.
3. Si ENABLE_DOCKER_PUBLISH=true, publica la imagen verificada en Docker Hub con etiquetas del commit y latest.
4. EC2 revisa latest cada cinco minutos con un timer de systemd. Si cambia, prueba la imagen en un puerto local antes de actualizar el servicio publico en el puerto 3300.
5. El despliegue conserva el contenedor anterior como redes2web-backup y lo restaura si falla la nueva version.

## Configuracion de GitHub

- Secret DOCKER_USER: usuario de Docker Hub.
- Secret DOCKER_PASSWORD: token con permisos de lectura y escritura.
- Variable ENABLE_DOCKER_PUBLISH: true, una vez configurados ambos secretos.

Las llaves de AWS no se guardan en GitHub. La descarga de la imagen publica no necesita un token en EC2.

## Instalar despliegue en EC2

Requiere Docker, curl y flock. Copiar los archivos deploy/ a la instancia y ejecutar:

```sh
sudo install -m 755 deploy/deploy.sh /usr/local/sbin/redes2web-deploy
sudo install -m 644 deploy/redes2web-deploy.service /etc/systemd/system/
sudo install -m 644 deploy/redes2web-deploy.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now redes2web-deploy.timer
sudo systemctl start redes2web-deploy.service
```

## Consultar estado

```sh
sudo systemctl list-timers redes2web-deploy.timer
sudo journalctl -u redes2web-deploy.service -n 40 --no-pager
sudo docker ps
curl --fail http://127.0.0.1:3300/
```

## Pruebas locales

```sh
pip install -r requirements.txt
python -m unittest discover -s tests -v
```

El servidor de desarrollo se ejecuta con python app.py. El contenedor utiliza Gunicorn.
