DO $$
DECLARE
  v_user_id uuid;
  v_account_id uuid;
  v_cat_food uuid;
  v_cat_transport uuid;
  v_cat_salary uuid;
BEGIN
  -- 1. Obtener el ID del usuario por su email
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'a440267976@my.uvm.edu.mx' LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario con email a440267976@my.uvm.edu.mx no encontrado en auth.users';
  END IF;

  -- 2. Upsert Perfil (Crear perfil simulado)
  INSERT INTO public.profiles (id, first_name, last_name, phone, avatar_url, updated_at)
  VALUES (
    v_user_id, 
    'Alejandro', 
    'Estudiante UVM', 
    '5551234567', 
    'https://ui-avatars.com/api/?name=Alejandro+UVM&background=0D8ABC&color=fff', 
    now()
  )
  ON CONFLICT (id) DO UPDATE 
  SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone, avatar_url = EXCLUDED.avatar_url;

  -- 3. Upsert Cuenta Bancaria (Crearla y asignarle un saldo inicial de prueba)
  SELECT id INTO v_account_id FROM public.accounts WHERE user_id = v_user_id LIMIT 1;
  
  IF v_account_id IS NULL THEN
    INSERT INTO public.accounts (user_id, account_type, account_number, balance, currency)
    VALUES (v_user_id, 'checking', '0123456789', 15450.50, 'MXN')
    RETURNING id INTO v_account_id;
  ELSE
    UPDATE public.accounts SET balance = 15450.50 WHERE id = v_account_id;
  END IF;

  -- 4. Sembrar Categorías Base (Se insertarán si la tabla está vacía)
  IF NOT EXISTS (SELECT 1 FROM public.categories LIMIT 1) THEN
    INSERT INTO public.categories (name, icon, color) VALUES ('Comida', 'restaurant', '#FF5722');
    INSERT INTO public.categories (name, icon, color) VALUES ('Transporte', 'directions_car', '#2196F3');
    INSERT INTO public.categories (name, icon, color) VALUES ('Nómina', 'work', '#4CAF50');
  END IF;

  -- 5. Sembrar Contactos
  -- Primero limpiamos contactos viejos para evitar duplicados si se corre varias veces
  DELETE FROM public.contacts WHERE owner_id = v_user_id;

  INSERT INTO public.contacts (owner_id, alias, account_number, bank_name)
  VALUES (v_user_id, 'Mamá', '012345678901234567', 'BBVA');
  
  INSERT INTO public.contacts (owner_id, alias, account_number, bank_name)
  VALUES (v_user_id, 'Renta Departamento', '987654321098765432', 'Santander');

  INSERT INTO public.contacts (owner_id, alias, account_number, bank_name)
  VALUES (v_user_id, 'Netflix Suscripción', '000000000000000000', 'Tarjeta Digital');

  -- 6. Sembrar Transacciones (Historial de Movimientos)
  -- Limpiamos las de este usuario para que cuadre exacto con el saldo
  DELETE FROM public.transactions WHERE user_id = v_user_id;

  -- +$20,000.00
  INSERT INTO public.transactions (user_id, amount, description, status, created_at)
  VALUES (v_user_id, 20000.00, 'Depósito de Nómina UVM', 'completed', now() - interval '5 days');

  -- -$1,250.50
  INSERT INTO public.transactions (user_id, amount, description, status, created_at)
  VALUES (v_user_id, -1250.50, 'Supermercado Walmart', 'completed', now() - interval '4 days');

  -- -$3,000.00
  INSERT INTO public.transactions (user_id, amount, description, status, created_at)
  VALUES (v_user_id, -3000.00, 'Transferencia a Renta Departamento', 'completed', now() - interval '2 days');

  -- -$89.00
  INSERT INTO public.transactions (user_id, amount, description, status, created_at)
  VALUES (v_user_id, -89.00, 'Starbucks Coffee', 'completed', now() - interval '1 day');

  -- -$210.00 (Pendiente)
  INSERT INTO public.transactions (user_id, amount, description, status, created_at)
  VALUES (v_user_id, -210.00, 'Transferencia a Mamá', 'pending', now());

END $$;
