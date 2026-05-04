# Ecart Banking

Ecart Banking es una aplicación móvil desarrollada en **Flutter** para el Proyecto Integrador (Etapa 3) de la Universidad del Valle de México (UVM). 
Implementa operaciones completas de CRUD (Crear, Leer, Actualizar, Eliminar) mediante una arquitectura Cliente-Servidor (BaaS) integrada con **Supabase** (PostgreSQL).

## Características

- **Autenticación (Supabase Auth):** Registro e inicio de sesión seguro con correo electrónico y contraseña.
- **Dashboard de Cuenta:** Visualización en tiempo real del saldo disponible y el historial de transacciones recientes.
- **Operaciones CRUD:**
  - **Create:** Realizar "Nuevos Fondeos" a la cuenta o crear nuevos Contactos para transferencias.
  - **Read:** Lectura asíncrona de saldo, movimientos y lista de contactos desde la base de datos en la nube.
  - **Update:** Marcar transacciones pendientes como "Completadas" y actualizar datos en la pantalla "Mi Perfil".
  - **Delete:** Cancelar y borrar pagos del historial o eliminar contactos de la agenda.

## Estructura de la Base de Datos (Supabase)

La aplicación utiliza políticas de seguridad (RLS - Row Level Security) para proteger la información en las siguientes tablas:
- `profiles`: Datos de usuario (nombre, teléfono).
- `accounts`: Cuentas bancarias y saldo real.
- `transactions`: Historial de depósitos y retiros.
- `contacts`: Directorio de cuentas frecuentes o beneficiarios.

## 📦 Archivo APK Generado

Para facilitar la evaluación del proyecto, se ha compilado una versión Release de la aplicación para dispositivos Android.
El instalador oficial (`.apk`) generado se encuentra en la siguiente ruta dentro del proyecto:

```
build/app/outputs/flutter-apk/app-release.apk
```

## Requisitos para Ejecutar el Código Fuente

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / Xcode (Para simulación local)
- Archivo `.env` en la raíz del proyecto con las credenciales:
  ```env
  SUPABASE_URL=tu_supabase_url
  SUPABASE_ANON_KEY=tu_supabase_anon_key
  ```

## Ejecución Local

1. Instalar las dependencias del proyecto:
   ```bash
   flutter pub get
   ```
2. Ejecutar la aplicación:
   ```bash
   flutter run
   ```