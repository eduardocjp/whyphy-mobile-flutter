# WhyPhy Flutter

App mobile Flutter do WhyPhy.

## API local

Com o WhyPhy web rodando localmente na porta `3000`, habilite o reverse no Android físico:

```powershell
adb reverse tcp:3000 tcp:3000
```

Rode o app apontando para o backend local:

```powershell
flutter run --dart-define=WHY_PHY_API_BASE_URL=http://127.0.0.1:3000 --dart-define=WHY_PHY_WEB_BASE_URL=http://127.0.0.1:3000
```

Em produção, sem `dart-define`, o app usa `https://www.whyphy.com.br`.

## Validação

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug
```
