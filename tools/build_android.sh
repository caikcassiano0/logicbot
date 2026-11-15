#!/bin/sh
# Gera os instaladores Android do LogicBot (universal + um por tipo de processador)
# e assina com a chave do projeto (../chave_android/logicbot-release.jks).
# Uso: sh tools/build_android.sh <pasta_saida> <uber-apk-signer.jar>
set -e
OUT=${1:-build/android}; UBER=${2:-uber-apk-signer.jar}
KS=../chave_android/logicbot-release.jks
: "${LB_KS_PASS:?Defina a senha da chave antes: export LB_KS_PASS=suasenha}"
mkdir -p "$OUT"
cp export_presets.cfg /tmp/ep_backup.cfg
exporta() { # nome v7 arm64 x86 x86_64
  sed -i "s/architectures\/armeabi-v7a=.*/architectures\/armeabi-v7a=$2/; s/architectures\/arm64-v8a=.*/architectures\/arm64-v8a=$3/; s/architectures\/x86=.*/architectures\/x86=$4/; s/architectures\/x86_64=.*/architectures\/x86_64=$5/" export_presets.cfg
  godot --headless --path . --export-release "Android" "$OUT/tmp_$1.apk"
  java -jar "$UBER" -a "$OUT/tmp_$1.apk" --ks "$KS" --ksAlias logicbot --ksPass "$LB_KS_PASS" --ksKeyPass "$LB_KS_PASS" -o "$OUT/assinados"
  mv "$OUT/assinados/tmp_$1-aligned-signed.apk" "$OUT/LogicBot-$1.apk"; rm -f "$OUT/tmp_$1.apk"
}
exporta universal true true true true
exporta arm64 false true false false
exporta arm32 true false false false
exporta x86_64 false false false true
cp /tmp/ep_backup.cfg export_presets.cfg
rm -rf "$OUT/assinados"
