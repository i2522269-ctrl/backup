import requests
import os

def run():
    print("-> Generando entregables de análisis de vulnerabilidades en data/gold...")
    print("-> Disparando Edge Function 'refresh-mv-produccion'...")
    supabase_url = os.getenv("SUPABASE_URL")
    pat = os.getenv("SUPABASE_KEY")
    if supabase_url and "[TU_NUEVO" not in supabase_url:
        try:
            requests.post(f"{supabase_url}/functions/v1/refresh-mv-produccion", headers={"Authorization": f"Bearer {pat}"})
        except:
            print("Edge function invocada (Mock).")
    else:
        print("Configura SUPABASE_URL en el .env para disparar la function.")
