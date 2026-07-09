# ClaudeProjeler

Ev ve ofis bilgisayarları arasında proje dosyalarını ve Claude Code skill listesini senkronize etmek için kullanılır.

## Skilleri senkronize etme

Yeni bir bilgisayarda veya güncel skil listesini almak için:

```
git pull
powershell -ExecutionPolicy Bypass -File install-claude-skills.ps1
```

Yeni bir skill eklemek için `claude-skills.txt` dosyasına `plugin-adi@marketplace-adi` formatında bir satır ekleyip commit + push yap. Diğer bilgisayarda yukarıdaki iki komutu çalıştırmak yeterli.
