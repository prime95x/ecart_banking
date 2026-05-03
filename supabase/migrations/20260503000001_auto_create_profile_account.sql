-- Función que se ejecuta después de que un usuario se registra
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- 1. Crear perfil vacío
  INSERT INTO public.profiles (id)
  VALUES (new.id);

  -- 2. Crear cuenta bancaria en ceros
  INSERT INTO public.accounts (user_id, account_type, balance, currency)
  VALUES (new.id, 'checking', 0, 'MXN');

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger que escucha cuando se inserta un nuevo usuario en auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
