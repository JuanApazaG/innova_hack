# Configuración de Variables de Entorno

## Configurar API Keys

1. Copia el archivo `.env.example` y renómbralo a `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edita el archivo `.env` y reemplaza las credenciales:
   ```env
   GOOGLE_MAPS_API_KEY=tu_api_key_de_google_maps
   ```

3. **IMPORTANTE**: El archivo `.env` está en `.gitignore` y NO se subirá a Git por seguridad.

4. Ejecuta la aplicación:
   ```bash
   flutter pub get
   flutter run
   ```

## Obtener Google Maps API Key

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un proyecto o selecciona uno existente
3. Activa la API de Google Maps
4. Crea credenciales (API Key)
5. Copia la clave y pégala en tu archivo `.env`

## Notas de Seguridad

- ✅ El archivo `.env` contiene información sensible y está excluido de Git
- ✅ Comparte `.env.example` con tu equipo como plantilla
- ✅ Cada desarrollador debe crear su propio archivo `.env`
- ⚠️ NUNCA subas el archivo `.env` a repositorios públicos
