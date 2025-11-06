#!/usr/bin/env python3
# ============================================
# 🛰️ PatagoniaFiber NetDiag v1.5
# Diagnóstico de red avanzado para ISPs
# ============================================

import subprocess, sys, re, socket, threading, itertools, time
from datetime import datetime
from pathlib import Path
from colorama import Fore, init
init(autoreset=True)

# ---------- Spinner visual ----------
def spinner(texto, stop_event):
    for c in itertools.cycle(["|", "/", "-", "\\"]):
        if stop_event.is_set():
            break
        sys.stdout.write(f"\r{Fore.CYAN}[🔍] {texto}... {c}")
        sys.stdout.flush()
        time.sleep(0.15)
    sys.stdout.write("\r" + " " * 60 + "\r")

def run(cmd, texto=None):
    stop_event = threading.Event()
    if texto:
        t = threading.Thread(target=spinner, args=(texto, stop_event))
        t.start()
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        out = e.output
    finally:
        if texto:
            stop_event.set()
            t.join()
    return out.strip()

def limpiar(texto):
    return re.sub(r"\x1B\[[0-?]*[ -/]*[@-~]", "", texto)

# ---------- DNS ----------
def check_dns(domain):
    out = run(f"dig +short {domain} @8.8.8.8", "Resolviendo DNS")
    if not out:
        return None, f"{Fore.RED}❌ No resolvió"
    ip = out.splitlines()[-1].strip()
    return ip, f"{Fore.GREEN}✅ {ip}"

# ---------- PING ----------
def check_ping(ip):
    out = run(f"ping -c 4 {ip}", "Enviando ping")
    if "bytes from" not in out:
        return f"{Fore.RED}❌ No responde"
    avg = re.findall(r"= ([\d\.]+)/", out)
    return f"{Fore.GREEN}✅ Promedio {avg[0]} ms" if avg else f"{Fore.GREEN}✅ OK"

# ---------- TRACEROUTE ----------
def check_traceroute(ip):
    cmd = f"traceroute -m 20 {ip}" if "BusyBox" not in run("traceroute --help") else f"traceroute {ip}"
    out = run(cmd, "Ejecutando traceroute")
    hops = len([l for l in out.splitlines() if re.match(r'^\s*\d+', l)])
    return hops, out or "No se pudo ejecutar traceroute."

# ---------- TCP/443 ----------
def check_tcp_port(domain, port=443, timeout=5):
    sys.stdout.write(f"{Fore.CYAN}[🔍] Verificando puerto TCP {port}...\r")
    sys.stdout.flush()
    try:
        with socket.create_connection((domain, port), timeout=timeout):
            sys.stdout.write(" " * 60 + "\r")
            return f"{Fore.GREEN}✅ TCP {port} abierto"
    except Exception as e:
        sys.stdout.write(" " * 60 + "\r")
        return f"{Fore.RED}❌ TCP {port} cerrado o filtrado ({e})"

# ---------- HTTPS ----------
def check_https(domain):
    out = run(f"curl -Is --max-time 8 https://{domain}", "Chequeando HTTPS")
    if "HTTP/" in out:
        return f"{Fore.GREEN}✅ {out.splitlines()[0]}"
    if "Connection timed out" in out or "Failed" in out:
        return f"{Fore.RED}❌ Timeout o bloqueo remoto"
    return f"{Fore.YELLOW}⚠️ Resultado inesperado"

# ---------- SSL ----------
def check_ssl(domain):
    out = run(f"echo | openssl s_client -connect {domain}:443 -servername {domain} 2>/dev/null | "
              f"openssl x509 -noout -dates -issuer -subject", "Leyendo certificado SSL")
    if not out:
        return f"{Fore.RED}❌ No se pudo obtener certificado"
    return f"{Fore.GREEN}✅ Certificado válido\n{out}"

# ---------- WHOIS ----------
def whois_ip(ip):
    return run(f"whois {ip} | grep -E 'OrgName|owner|country|netname|descr' | head -n 6",
               "Consultando WHOIS") or "No WHOIS info"

# ---------- IP pública ----------
def check_public_ip():
    for srv in ["ifconfig.me", "icanhazip.com", "ipinfo.io/ip"]:
        ip = run(f"curl -s --max-time 5 {srv}", f"Detectando IP pública ({srv})")
        if re.match(r"^\d+\.\d+\.\d+\.\d+$", ip):
            break
    ptr = run(f"host {ip}", "Consultando PTR")
    if "not found" in ptr or "NXDOMAIN" in ptr:
        return ip, "sin PTR"
    return ip, ptr

# ---------- Reporte ----------
def generar_reporte(domain, datos, trace):
    ts = datetime.now().strftime("%Y%m%d_%H%M")
    path = Path(f"/tmp/netdiag_{ts}.txt")
    with open(path, "w") as f:
        for k, v in datos.items():
            f.write(f"{k}: {limpiar(str(v))}\n")
        f.write("\nTraceroute:\n" + trace + "\n")
    return path

# ---------- MAIN ----------
def main():
    if len(sys.argv) < 2:
        print("Uso: ./diagnet <dominio>")
        sys.exit(1)
    domain = sys.argv[1]
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    print(f"{Fore.CYAN}{'─'*55}")
    print(f"{Fore.CYAN}🔎 PatagoniaFiber NetDiag v1.5")
    print(f"{Fore.WHITE}Dominio: {domain}")
    print(f"{Fore.WHITE}Fecha: {now}")
    print(f"{Fore.CYAN}{'─'*55}")

    ip, dns_out = check_dns(domain)
    tcp_out = check_tcp_port(domain)
    https_out = check_https(domain)
    ssl_out = check_ssl(domain)
    ip_pub, ptr = check_public_ip()

    if ip:
        ping_out = check_ping(ip)
        hops, trace = check_traceroute(ip)
        whois_out = whois_ip(ip_pub)
    else:
        ping_out, trace, hops, whois_out = "❌ Sin IP", "Sin traceroute", 0, "N/A"

    print(f"🌐 DNS:  {dns_out}")
    print(f"📶 Ping:  {ping_out}")
    print(f"🚀 Traceroute: {Fore.GREEN if hops else Fore.RED}{hops or '?'} saltos")
    print(f"🔌 TCP 443: {tcp_out}")
    print(f"🔒 HTTPS: {https_out}")
    print(f"📜 SSL:  {ssl_out.splitlines()[0]}")
    print(f"🌍 IP pública: {Fore.YELLOW}{ip_pub} ({Fore.RED if 'sin' in ptr else Fore.GREEN}{ptr})")
    print(f"🏢 WHOIS: {whois_out.splitlines()[0] if whois_out else 'N/A'}")
    print(f"{Fore.CYAN}{'─'*55}")

    resumen = []
    if "Timeout" in https_out or "No responde" in ping_out:
        resumen.append("⚠️ Posible bloqueo por reputación o firewall remoto.")
    elif "HTTP/" in https_out:
        resumen.append("✅ Conectividad general correcta.")
    elif not ip:
        resumen.append("❌ No se resolvió DNS.")
    else:
        resumen.append("⚠️ Diagnóstico inconcluso, revisar manualmente.")

    print(f"{Fore.WHITE}🧠 Diagnóstico resumido:")
    for r in resumen:
        print(f"  {r}")

    datos = {
        "Dominio": domain,
        "DNS": dns_out,
        "Ping": ping_out,
        "Saltos": hops,
        "TCP_443": tcp_out,
        "HTTPS": https_out,
        "SSL": ssl_out,
        "IP_Publica": ip_pub,
        "PTR": ptr,
        "WHOIS": whois_out,
        "Diagnóstico": ", ".join(resumen)
    }

    path = generar_reporte(domain, datos, trace)
    print(f"{Fore.CYAN}📁 Reporte guardado en: {path}")
    print(f"{Fore.CYAN}{'─'*55}")

if __name__ == "__main__":
    main()
