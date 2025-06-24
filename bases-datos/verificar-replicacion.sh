#!/bin/bash
echo "=== Verificación de Replicación MySQL ==="

echo "📊 Estado de BD1 (Maestro):"
mysql -h 192.168.218.102 -u usuario_bd -pclave_bd_segura_123 -e "
    USE sistema_clientes;
    SELECT 'Maestro' as servidor, COUNT(*) as total_clientes FROM clientes;
    SHOW MASTER STATUS;
"

echo ""
echo "📊 Estado de BD2 (Esclavo):"
mysql -h 192.168.218.104 -u usuario_bd -pclave_bd_segura_123 -e "
    USE sistema_clientes;
    SELECT 'Esclavo' as servidor, COUNT(*) as total_clientes FROM clientes;
    SHOW SLAVE STATUS\G
"

echo ""
echo "💾 Estado del RAID 1:"
ssh usuario@192.168.218.104 "sudo mdadm --detail /dev/md0 | grep -E 'State|Active Devices'"
