import os
from dotenv import load_dotenv
from scripts import ingestion, transformation, curated

load_dotenv()

def check_joanfqe_bit():
    print("[Seguridad] Verificando servicio joanfqe-bit...")
    # Alerta si el servicio está caído
    try:
        # Aquí iría el fetch real a joanfqe-bit
        pass
    except Exception as e:
        print("ALERTA: joanfqe-bit parece estar pausado o inactivo.")

def main():
    print("Iniciando Pipeline Medallion - Backup 2.0")
    check_joanfqe_bit()
    
    print("\n=== CAPA BRONZE ===")
    ingestion.run()
    
    print("\n=== CAPA SILVER ===")
    transformation.run()
    
    print("\n=== CAPA GOLD ===")
    curated.run()

if __name__ == "__main__":
    main()
