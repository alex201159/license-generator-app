# LC Carga no Windows e acesso pela rede

## Usar o aplicativo no PC servidor

1. Extraia a pasta inteira do pacote `LC-Carga-Windows.zip` para uma pasta do PC.
2. Abra `license_generator_app.exe` uma vez. Ele cadastra a inicialização automática para o usuário atual do Windows. Mantenha os arquivos `.dll` e a pasta `data` ao lado do executável, em uma pasta permanente.
3. O servidor inicia automaticamente na porta **8787** após carregar o histórico. Abra a aba **Rede** para consultar o endereço e o status.
4. Copie um dos endereços mostrados, por exemplo `http://192.168.1.50:8787`, e a **senha de acesso pela rede**.
5. Em outro computador ou celular na mesma rede, abra esse endereço no navegador e informe a senha fixa **88336092**.

O navegador permite gerar licenças, informar valores, copiar as chaves e consultar **Histórico** e **Expiradas**, com pastas por mês de geração. Os dados são gravados no PC servidor e aparecem também no aplicativo. As telas do navegador atualizam o histórico a cada 10 segundos ou pelo botão **Atualizar**.

O PC precisa permanecer ligado, sem suspensão, e com o aplicativo aberto. Ao fechar o aplicativo, o endereço para de responder. Ao reabrir, o acesso é iniciado automaticamente com a mesma senha **88336092**. A senha de acesso é diferente da chave secreta que assina as licenças.

## Iniciar junto com o Windows

Depois da primeira execução no Windows, o aplicativo abre automaticamente **após entrar na mesma conta de usuário**, minimizado na barra de tarefas. O servidor é ativado na porta **8787** com a senha **88336092**. Não é necessário abrir o programa manualmente a cada login.

Essa configuração usa a entrada `LCCargaServer` na chave `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`, com o caminho do executável e o argumento `--startup`. A inicialização segue o mecanismo de [programas executados no login do Windows](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys). Ela depende do login do usuário e não é um serviço executado antes da tela de login.

Ao abrir o executável novamente, a janela já existente é restaurada. O programa mantém uma única instância para evitar dois servidores disputando a mesma porta. Mantenha a janela aberta ou minimizada; fechar pelo **X** encerra o servidor até abrir o programa novamente ou entrar novamente no Windows.

Se mover a pasta do programa, abra o executável no novo local uma vez para atualizar o cadastro. Para desabilitar a inicialização automática, use **Gerenciador de Tarefas → Aplicativos de inicialização** e desabilite a entrada correspondente ao LC Carga ou `license_generator_app`.

O pacote inclui uma verificação para executar no PC Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\VERIFICAR_INICIALIZACAO.ps1
```

Ela confere o cadastro do executável, a resposta do servidor com a senha configurada e a proteção contra instâncias duplicadas. Depois, saia e entre novamente na conta para validar o início após o login. A verificação mantém o aplicativo aberto e não altera o histórico.

É possível desativar o servidor manualmente pela aba **Rede**. Se a porta estiver ocupada, o aplicativo informa o erro nessa aba; você pode escolher outra porta e ativar novamente.

O endereço usa HTTP e foi preparado para a rede local. Acesso de fora dessa rede exige outra configuração. Não configure encaminhamento dessa porta no roteador. Se o IP do PC mudar, use o novo endereço mostrado na aba Rede; uma reserva DHCP no roteador evita essa mudança.

## Firewall do Windows

Se o Windows pedir permissão, permita o aplicativo em **redes privadas**. A rede utilizada no PC deve estar marcada como privada.

Se o acesso continuar bloqueado, abra o PowerShell **como administrador**, entre na pasta extraída e execute o script incluído:

```powershell
powershell -ExecutionPolicy Bypass -File .\HABILITAR_REDE.ps1
```

Para uma porta diferente, use a mesma porta do aplicativo:

```powershell
powershell -ExecutionPolicy Bypass -File .\HABILITAR_REDE.ps1 -Port 8788
```

O script cria uma regra para esse executável, essa porta TCP, o perfil privado e os dispositivos da sub-rede local. A configuração segue os parâmetros de [New-NetFirewallRule da Microsoft](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule).

## Compilar pela nuvem, usando apenas o Mac

O workflow `.github/workflows/windows-release.yml` usa um Windows do GitHub Actions para compilar o projeto Flutter. Você pode acompanhar e baixar o resultado pelo navegador no Mac, sem instalar Windows localmente.

1. Abra o repositório privado do projeto no GitHub e entre em **Actions**.
2. Selecione **Gerar aplicativo Windows** e clique em **Run workflow** para compilar novamente.
3. Aguarde a compilação e as verificações terminarem com sucesso.
4. Abra a execução e baixe **LC-Carga-Windows-x64** na seção **Artifacts**.
5. Extraia o arquivo baixado e depois `LC-Carga-Windows.zip`. Copie a pasta completa para o PC Windows e abra `license_generator_app.exe` uma vez.

O build usa Flutter **3.41.4**, executa a análise e os testes, compila o `.exe`, verifica o servidor e a inicialização minimizada e disponibiliza o pacote por 14 dias. As bibliotecas redistribuíveis do Visual C++ são incluídas quando encontradas na instalação do compilador.

Os dados do histórico não fazem parte do repositório nem do pacote de compilação. A transferência dos registros existentes é feita conforme a seção abaixo. A máquina Windows da nuvem serve para compilar e testar; o servidor definitivo continuará rodando no seu PC Windows.

## Compilar diretamente em um PC Windows

A compilação precisa ser feita no Windows, com Flutter e Visual Studio com a carga **Desenvolvimento para desktop com C++**, conforme o [guia oficial do Flutter](https://docs.flutter.dev/platform-integration/windows/setup).

Na pasta do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1
```

O script executa os testes, compila o programa e gera `dist\LC-Carga-Windows.zip` com o executável, DLLs, dados do Flutter e estas instruções. No PC de destino, pode ser necessário instalar o Microsoft Visual C++ Redistributable; os requisitos de distribuição estão na [documentação do Flutter para Windows](https://docs.flutter.dev/platform-integration/windows/building).

## Dados e mudança do Mac para o Windows

O arquivo `license_history.json` contém clientes, chaves, datas de geração, vencimentos e valores. Ele fica na pasta de dados do aplicativo, separado do executável. Os navegadores consultam esse arquivo pelo servidor e não guardam uma base independente.

Com os metadados atuais do aplicativo, no Windows o arquivo fica em:

```text
%APPDATA%\com.example\license_generator_app\license_history.json
```

No Mac com o aplicativo em sandbox, fica em:

```text
~/Library/Containers/com.example.licenseGeneratorApp/Data/Library/Application Support/com.example.licenseGeneratorApp/license_history.json
```

Para levar o histórico atual ao Windows, feche o aplicativo nos dois computadores, faça uma cópia de segurança do arquivo de destino se ele existir e copie o arquivo do Mac para a pasta indicada no Windows. Crie a pasta se necessário. Depois abra o aplicativo no Windows. Copiar apenas o projeto ou o executável não transfere o histórico.

## Verificações realizadas no desenvolvimento

O servidor é testado com requisições HTTP reais em `127.0.0.1`, incluindo senha, geração de chaves compatíveis, persistência, gravações simultâneas e recuperação após erro de escrita. O executável e o Firewall do Windows precisam de validação no PC Windows; os testes no macOS não substituem essa verificação.
