import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'network_access.dart';
import 'network_session_controller.dart';

class NetworkSettingsPanel extends StatefulWidget {
  const NetworkSettingsPanel({
    super.key,
    required this.session,
    required this.canStart,
  });

  final NetworkSessionController session;
  final bool canStart;

  @override
  State<NetworkSettingsPanel> createState() => _NetworkSettingsPanelState();
}

class _NetworkSettingsPanelState extends State<NetworkSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  final _portController = TextEditingController(text: '$defaultNetworkPort');
  String? _error;
  bool _showPassword = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _toggle() async {
    final session = widget.session;
    if (session.busy) return;
    final port = int.tryParse(_portController.text);
    if (session.info == null && (port == null || port < 1 || port > 65535)) {
      setState(() => _error = 'Informe uma porta entre 1 e 65535.');
      return;
    }
    setState(() => _error = null);
    if (session.info != null) {
      await session.stop();
    } else {
      await session.start(port: port!);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copiado.')));
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final session = widget.session;
    final info = session.info;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const PageStorageKey('network-settings'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.lan_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Acesso pela rede',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Abra o sistema pelo navegador de outro computador ou celular '
                'para gerar chaves e consultar o mesmo histórico.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Os dispositivos precisam estar na mesma rede. '
                'Mantenha este computador ligado e o aplicativo aberto.',
              ),
              const SizedBox(height: 24),
              if (!session.isSupported)
                const Text(
                  'Ative este acesso pelo aplicativo instalado no Windows, macOS ou Linux.',
                )
              else ...[
                TextField(
                  controller: _portController,
                  enabled: info == null && !session.busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Porta de acesso',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.settings_ethernet),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: session.busy || (info == null && !widget.canStart)
                      ? null
                      : _toggle,
                  icon: Icon(info == null ? Icons.wifi : Icons.wifi_off),
                  label: Text(
                    session.busy
                        ? 'Aguarde...'
                        : info == null
                        ? 'Ativar acesso pela rede'
                        : 'Desativar acesso pela rede',
                  ),
                ),
                if (!widget.canStart && info == null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Carregue o histórico antes de ativar o acesso pela rede.',
                  ),
                ],
              ],
              if ((_error ?? session.error) != null) ...[
                const SizedBox(height: 16),
                Text(
                  (_error ?? session.error)!,
                  style: TextStyle(color: colors.error),
                ),
              ],
              if (info != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Endereço para abrir no navegador',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final url in info.urls)
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          url,
                          key: PageStorageKey('network-address-$url'),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copy(url),
                        tooltip: 'Copiar endereço',
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  key: ValueKey('network-password-${info.password}'),
                  initialValue: info.password,
                  readOnly: true,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Senha de acesso pela rede',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          tooltip: _showPassword
                              ? 'Ocultar senha'
                              : 'Mostrar senha',
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copy(info.password),
                          tooltip: 'Copiar senha de acesso',
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'O servidor inicia automaticamente ao abrir o aplicativo. '
                  'A senha de acesso permanece a mesma ao reiniciar.',
                ),
                const SizedBox(height: 18),
                const Text(
                  'No Windows, permita o acesso do aplicativo em redes privadas '
                  'se o Firewall solicitar.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
