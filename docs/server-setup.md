
# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

Для практической работы №5 была создана виртуальная машина devops-vm в Oracle VirtualBox.

Операционная система — Ubuntu Server 24.04.5 LTS. Машине выделено 2048 МБ оперативной памяти, 2 ядра процессора и 25 ГБ дискового пространства.

## 2. Сетевые интерфейсы

Используются два сетевых адаптера.

Первый адаптер — NAT. IP-адрес Ubuntu: 10.0.2.15. Он обеспечивает подключение к Интернету и загрузку обновлений.

Второй адаптер — Host-only. IP-адрес Ubuntu: 192.168.56.101. Он предназначен для прямого взаимодействия виртуальной машины с Windows.

## 3. Правило проброса портов

Для удалённого подключения используется SSH.

Тип подключения первого адаптера — NAT.

Настроено правило:
- Название: ssh
- Протокол: TCP
- Адрес хоста: 127.0.0.1
- Порт хоста: 2222
- Порт гостевой системы: 2222

## 4. Учётные записи

При установке Ubuntu создан пользователь student.

Для дальнейшего администрирования создан пользователь devops, включённый в группы devops, sudo и users.

Пользователь devops подключается к серверу по SSH с использованием ключа ED25519.

Закрытый ключ хранится на Windows в ~/.ssh/devops.

Открытый ключ добавлен на сервер в /home/devops/.ssh/authorized_keys.

Для каталога .ssh установлены права 700, для authorized_keys — 600.

## 5. Служба SSH

Сервер OpenSSH установлен при установке Ubuntu.

Основной файл конфигурации:
/etc/ssh/sshd_config

Дополнительный файл:
/etc/ssh/sshd_config.d/99-hardening.conf

Настроены следующие параметры:

Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2

В файле /etc/ssh/sshd_config.d/50-cloud-init.conf закомментирована строка PasswordAuthentication yes.

Для применения настроек отключён ssh.socket и включён ssh.service.

Проверка конфигурации выполняется командой:
sudo sshd -t

Действующие параметры проверяются командой:
sudo sshd -T

Подключение с Windows выполняется командой:
ssh devops

## 6. Правила межсетевого экрана

Для фильтрации сетевых соединений используется UFW.

Политика входящих соединений — deny.
Политика исходящих соединений — allow.

Настроены правила:

2222/tcp — LIMIT IN, SSH
80/tcp — ALLOW IN, HTTP
443/tcp — ALLOW IN, HTTPS

Журналирование UFW установлено на уровень medium.

Проверка состояния:
sudo ufw status verbose

## 7. Локальное доменное имя

В файл hosts операционной системы Windows добавлена запись:

192.168.56.101 devops.local

В Ubuntu настроено полное доменное имя:
devops-vm.devops.local

Проверка выполняется командой:
hostname -f

## 8. Снимки состояния

В VirtualBox созданы три снимка:

01-clean-install — после первоначальной установки Ubuntu Server.

02-keys-configured — после создания пользователя devops и настройки SSH-ключей.

03-ssh-hardened — после усиления защиты SSH и перехода на порт 2222.

Снимки предназначены для восстановления состояния виртуальной машины при ошибках конфигурации.

## 9. Восстановление конфигурации

Восстановление начинается со снимка 01-clean-install.

Для повторной настройки необходимо:
1. Создать пользователя devops и добавить его в группу sudo.
2. Добавить открытый SSH-ключ в authorized_keys.
3. Установить права 700 и 600.
4. Создать файл 99-hardening.conf.
5. Отключить конфликтующую настройку PasswordAuthentication в 50-cloud-init.conf.
6. Переключить SSH на порт 2222 и изменить проброс портов VirtualBox.
7. Настроить UFW с политикой deny incoming и разрешить порты 2222, 80 и 443.
8. Настроить доменное имя devops.local.
9. Запустить scripts/audit.sh и проверить результаты.


### Команды восстановления сервера

Создание пользователя и выдача прав:

```bash
sudo adduser devops
sudo usermod -aG sudo devops
groups devops
```

Настройка SSH-ключей:

```bash
sudo install -d -m 700 -o devops -g devops /home/devops/.ssh
sudo touch /home/devops/.ssh/authorized_keys
sudo chown devops:devops /home/devops/.ssh/authorized_keys
sudo chmod 600 /home/devops/.ssh/authorized_keys
```

После этого открытый SSH-ключ с Windows необходимо добавить в authorized_keys.

Настройка SSH:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
```

В файл добавить:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

В файле 50-cloud-init.conf закомментировать PasswordAuthentication yes.

После проверки синтаксиса переключить службу:

```bash
sudo sshd -t
sudo systemctl disable --now ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh
```

Затем изменить порт гостя в правиле VirtualBox с 22 на 2222 и проверить новое SSH-подключение, не закрывая старое.

Настройка UFW:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw enable
sudo ufw logging medium
sudo ufw status verbose
```

Настройка имени сервера:

```bash
sudo hostnamectl set-hostname devops-vm
sudo nano /etc/hosts
hostname -f
```

В /etc/hosts необходимо указать:

```text
127.0.1.1 devops-vm.devops.local devops-vm
```

На Windows в файл hosts добавить:

```text
192.168.56.101 devops.local
```

После завершения восстановления выполнить аудит:

```bash
bash ~/scripts/audit.sh
echo $?
```

Ожидается 6 успешных проверок и код возврата 0.
