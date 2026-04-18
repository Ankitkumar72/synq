-- Add specific emails to be automatically granted 'pro' plan tier on sign up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_plan_tier TEXT := 'free';
BEGIN
  IF COALESCE(NEW.email, '') IN (
    'loudpixel73@gmail.com',
    '14420068m@gmail.com',
    'pixelyouto1@gmail.com',
    'test1main@gmail.com',
    'synq.app.labs@gmail.com'
  ) THEN
    v_plan_tier := 'pro';
  END IF;

  INSERT INTO public.profiles (id, email, name, plan_tier, created_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    v_plan_tier,
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update any existing accounts that may already be in the database
UPDATE public.profiles
SET plan_tier = 'pro'
WHERE email IN (
  'loudpixel73@gmail.com',
  '14420068m@gmail.com',
  'pixelyouto1@gmail.com',
  'test1main@gmail.com',
  'synq.app.labs@gmail.com'
);
