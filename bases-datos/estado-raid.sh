#!/bin/bash
echo "=== Estado del RAID 1 en BD2 ==="

echo "📊 Información general del RAID:"
sudo mdadm --detail /dev/md0

echo ""
echo "📈 Estado en tiempo real:"
cat /proc/mdstat

echo ""
echo "💾 Uso del disco:"
df -h /mnt/raid1

echo ""
echo "🔍 Verificación de errores:"
sudo dmesg | grep -i raid | tail -5
