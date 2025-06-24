#!/bin/bash
echo "=== Estado del Balanceador NGINX ==="

# Verificar servicio NGINX
if systemctl is-active nginx > /dev/null; then
    echo "✅ NGINX: Activo"
else
    echo "❌ NGINX: Inactivo"
fi

# Verificar conectividad a App1
if curl -s --max-time 5 http://192.168.218.101:3000 > /dev/null; then
    echo "✅ App1: Disponible"
else
    echo "❌ App1: No disponible"
fi

# Verificar conectividad a App2
if curl -s --max-time 5 http://192.168.218.103:3000 > /dev/null; then
    echo "✅ App2: Disponible"
else
    echo "❌ App2: No disponible"
fi

# Verificar balanceador
if curl -s --max-time 5 http://192.168.218.100 > /dev/null; then
    echo "✅ Balanceador: Funcionando"
else
    echo "❌ Balanceador: Error"
fi
