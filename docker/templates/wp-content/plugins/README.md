# Plantilla de Plugins Predeterminados

Coloca en este directorio cualquier plugin (carpeta descomprimida o archivos PHP) que desees que esté disponible automáticamente en cada nueva implementación del proyecto.

Cuando se ejecute `docker compose up` por primera vez con un directorio `web/wp-content` nuevo o vacío, los plugins ubicados aquí se copiarán automáticamente a `web/wp-content/plugins/`.
