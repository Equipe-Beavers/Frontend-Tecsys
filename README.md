# Frontend Tecsys

Consulte a [documentação da interface de critérios de instalação](docs/InstallCriteriaInterface.md) para executar e validar a biblioteca de critérios.

## Requisitos

- Windows 10 ou superior
- Git
- Flutter SDK
- Android Studio (para Android/emulador)
- Chrome (para rodar em web)

## Instalar o Flutter no Windows

1. Baixe o Flutter SDK em:
   https://docs.flutter.dev/get-started/install/windows
2. Extraia a pasta em algum local estável, por exemplo:
   `C:\src\flutter`
3. Adicione o diretório do Flutter ao PATH do sistema:
   - Abra as Variáveis de ambiente
   - Edite o PATH do usuário
   - Adicione `C:\src\flutter\bin`
4. Feche e abra o terminal novamente.
5. Verifique se a instalação está correta:

```powershell
flutter --version
flutter doctor
```

Se o `flutter doctor` mostrar pendências, siga as orientações para instalar o Android SDK ou o Visual Studio Build Tools.

## Clonar e abrir o projeto

No terminal, execute:

```powershell
git clone https://github.com/Equipe-Beavers/Frontend-Tecsys.git
```

Se o projeto já estiver no computador, abra o PowerShell na pasta do projeto:

```powershell
cd C:\caminho\para\Frontend-Tecsys
```
## Instalar dependências

Dentro da pasta do projeto:

```powershell
flutter pub get
```

Isso baixa todas as dependências do arquivo `pubspec.yaml`.

## Rodar o app localmente

### 1) Web

```powershell
flutter run -d chrome
```

### 2) Android

Primeiro, confirme se o Android Studio e um emulador estão instalados:

```powershell
flutter devices
```

Depois rode:

```powershell
flutter run -d emulator-5554
```

Ou apenas:

```powershell
flutter run
```

### 3) Windows desktop

Se o ambiente do Windows estiver configurado:

```powershell
flutter run -d windows
```
