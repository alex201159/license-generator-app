# LC Carga — Gerador de licenças

Aplicativo Flutter com histórico persistente, valores em reais, pastas mensais,
aba de chaves expiradas e acesso por navegador na rede local.

Para desenvolver:

```sh
flutter pub get
flutter run -d macos
```

Para validar:

```sh
flutter analyze
flutter test
```

O servidor inicia automaticamente ao abrir o aplicativo, na porta **8787**, com
a senha fixa **88336092**. Abra **Rede** para consultar o endereço e usá-lo em
outro computador ou celular. As gerações pelo navegador
e pelo aplicativo usam o mesmo histórico no computador servidor.

No Windows, a primeira execução também cadastra o aplicativo para abrir
minimizado automaticamente após o login do usuário. Abrir o executável outra vez
restaura a janela existente, mantendo um único servidor.

As instruções para compilar e usar no Windows, configurar o Firewall e transferir
o histórico estão em [Acesso pela rede e Windows](docs/ACESSO_REDE.md).

O workflow **Gerar aplicativo Windows** compila e verifica o `.exe` no GitHub
Actions. No Mac, basta abrir a aba Actions do repositório e baixar o artefato
**LC-Carga-Windows-x64** após a execução terminar com sucesso.
