# LogicBot no Android

## Qual arquivo instalar
| Arquivo | Para quem |
|---|---|
| `LogicBot-arm64.apk` (35 MB) | **quase todos os celulares atuais** (64 bits) |
| `LogicBot-arm32.apk` (36 MB) | celulares antigos ou muito simples (32 bits) |
| `LogicBot-x86_64.apk` (36 MB) | Chromebooks com Intel/AMD e emuladores no PC |
| `LogicBot-universal.apk` (108 MB) | serve em **qualquer** um dos acima (na dúvida, este) |

Todos têm a mesma assinatura (chave em `../chave_android/`): dá para trocar de um para outro
sem desinstalar. Se o celular "esconder" o .apk no download, mande-o dentro de um .zip.

## Requisitos (valem para todas as marcas)
- Android **7.0 ou mais novo**.
- Placa de vídeo com **OpenGL ES 3.0** (praticamente todo celular de 2015 para cá).
- ~**250 MB** livres e, de preferência, **2 GB de RAM** ou mais.
- O jogo usa o modo gráfico **Compatibilidade (OpenGL)** no celular — o mais aceito por
  todos os fabricantes (evita problemas de drivers Vulkan em aparelhos de entrada).
- Não usa serviços do Google: funciona também em aparelhos sem Play Store (Huawei/Honor, Fire).

## Marcas
Funcionam (Android 7+): Samsung, Motorola, Xiaomi/Redmi/POCO, Infinix, Tecno, itel, Realme,
OPPO, OnePlus, vivo, LG, Nokia, Asus, Sony, Positivo, Multilaser, Lenovo, Huawei/Honor (EMUI/
MagicOS), Amazon Fire (Fire OS 7+), Chromebooks com Play Store.
Não funcionam: iPhone/iPad (iOS) e HarmonyOS NEXT (sistema da Huawei sem Android).

## Se não instalar
1. Instale pelo app **Arquivos/Meus arquivos** (não pela notificação do download).
2. Permita "instalar apps desconhecidos" para esse app.
3. Desligue por um momento a verificação do **Play Protect** e a do fabricante
   (Samsung: Bloqueador automático · Xiaomi: verificação de segurança · Infinix/Tecno: Phone Master).
4. Veja se há espaço livre.

Gerar de novo: `sh tools/build_android.sh <pasta> <uber-apk-signer.jar>`.
