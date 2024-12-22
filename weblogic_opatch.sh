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

binary_patches_path="$patch_directory_path/binary_patches"
if [ ! -d "$binary_patches_path" ]; then
    echo "'$binary_patches_path' dizini bulunamadı."
    exit 1
fi


find "$binary_patches_path" -type d \( -name "linux64" -o -name "generic" \) | while read -r platform_dir; do
    for patch_dir in "$platform_dir"/*; do
        if [ -d "$patch_dir" ]; then
            echo "Patch uygulanıyor: $patch_dir"
            apply_output=$("$weblogic_opatch_path" apply -silent "$patch_dir" 2>&1)
            if [[ $? -eq 0 ]]; then
                echo "OPatch başarılı $patch_dir"
            else
                echo "Patch hatası $patch_dir"
                echo "Hata Detayı $apply_output"
                
                # Conflict durumunu kontrolü
                if [[ "$apply_output" =~ Conflict\ with\ ([0-9]+) ]]; then
                    conflict_patch_id="${BASH_REMATCH[1]}"
                    echo "Conflict mevcut $conflict_patch_id"
                    
                    # Rollback işlemi
                    echo "Rollback başlatılıyor: $conflict_patch_id"
                    rollback_output=$("$weblogic_opatch_path" rollback -id "$conflict_patch_id" "$patch_dir" 2>&1)
                    if [[ $? -eq 0 ]]; then
                        echo "Rollback tamamlandı $conflict_patch_id"
                        
                        # Yeniden opatch
                        echo "OPatch yeniden uygulanıyor $patch_dir"
                        retry_output=$("$weblogic_opatch_path" apply -silent "$patch_dir" 2>&1)
                        if [[ $? -eq 0 ]]; then
                            echo "OPatch başarılı $patch_dir"
                        else
                            echo "Patch başarısız $patch_dir"
                            echo "Hata Detayı: $retry_output"
                        fi
                    else
                        echo "Rollback başarısız $conflict_patch_id"
                        echo "Hata Detayı: $rollback_output"
                    fi
                fi
            fi
        fi
    done
done

echo "Tüm opatch işlemleri tamamlandı."