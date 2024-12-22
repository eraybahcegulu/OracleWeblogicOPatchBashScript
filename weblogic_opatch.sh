#!/bin/bash

middleware_path=$1
patch_directory_path=$2
user=$3

if [ ! -d "$middleware_path" ]; then
    echo "'$middleware_path' bulunamadı."
    exit 1
fi

if [ ! -d "$patch_directory_path" ]; then
    echo "'$patch_directory_path' bulunamadı."
    exit 1
fi

# Kullanıcı kontrolü
if [ "$(whoami)" != "$user" ]; then
    echo "Script'i '$user' kullanıcısı ile çalıştırmalısınız."
    exit 1
fi

weblogic_opatch_path="$middleware_path/OPatch/opatch"
if [ ! -x "$weblogic_opatch_path" ]; then
    echo "'$weblogic_opatch_path' bulunamadı"
    exit 1
fi

echo "Middleware Path: $middleware_path"
echo "Patch Directory Path: $patch_directory_path"
read -p "Path onay (E/H): " confirm

if [[ "$confirm" == "E" || "$confirm" == "e" ]]; then
    echo "Onaylandı"
else
    echo "İptal edildi"
    exit 1
fi

owner=$(stat -c %U "$middleware_path")
if [ "$owner" != "$user" ]; then
  echo "Middleware Path'$middleware_path' '$user' kullanıcısına ait değil. Geçerli sahip: $owner."
  exit 1
fi

# Java işlemlerini sonlandırma
pids=$(pgrep -f java)
if [ -n "$pids" ]; then
    echo "$pids" | xargs -I {} echo "Sonlandırılıyor, pid: {}"
    if echo "$pids" | xargs kill -9; then
        echo "Tüm Java processleri başarıyla sonlandırıldı."
    else
        echo "Java processleri sonlandırılırken hata oluştu"
    fi
else
    echo "Çalışan Java processi bulunamadı"
fi