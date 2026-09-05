import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../config/colors.dart';
import '../../../services/driver_service.dart';
import '../../../services/api_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() =>
      _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final cpfController = TextEditingController();
  final birthDateController = TextEditingController();
  final cnhController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  PlatformFile? identificationDocument;
  PlatformFile? cnhDocument;
  PlatformFile? vehicleDocument;
  PlatformFile? selfieDocument;

  String driverType = 'moto';
  String cnhCategory = 'A';

  List<Map<String, String>> serviceCities = [];
  bool citiesLoading = true;
  bool citiesLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadServiceCities();
  }

  Future<void> _loadServiceCities() async {
    final result = await ApiService.getServiceCities();
    if (!mounted) return;

    final raw = result['cities'];
    final loaded = <Map<String, String>>[];
    if (result['success'] == true && raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final city = item['city']?.toString().trim() ?? '';
          final state = item['state']?.toString().trim().toUpperCase() ?? '';
          if (city.isNotEmpty && state.length == 2) {
            loaded.add({'city': city, 'state': state});
          }
        }
      }
    }

    setState(() {
      serviceCities = loaded;
      citiesLoading = false;
      citiesLoadFailed = result['success'] != true;
    });
  }

  final driverTypes = const [
    {
      'value': 'moto',
      'label': 'Mototáxi',
      'icon': Icons.two_wheeler,
    },
    {
      'value': 'carro',
      'label': 'Carro',
      'icon': Icons.directions_car,
    },
    {
      'value': 'delivery_moto',
      'label': 'Entrega de moto',
      'icon': Icons.delivery_dining,
    },
    {
      'value': 'delivery_bicicleta',
      'label': 'Entrega de bicicleta',
      'icon': Icons.pedal_bike,
    },
    {
      'value': 'delivery_pedestre',
      'label': 'Entrega a pé',
      'icon': Icons.directions_walk,
    },
  ];

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    stateController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    cpfController.dispose();
    birthDateController.dispose();
    cnhController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'selfie'
          ? const ['jpg', 'jpeg', 'png', 'webp']
          : const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      _showMessage('Não foi possível ler o arquivo selecionado.', error: true);
      return;
    }

    setState(() {
      switch (type) {
        case 'identification_document':
          identificationDocument = file;
          break;
        case 'cnh_document':
          cnhDocument = file;
          break;
        case 'vehicle_document':
          vehicleDocument = file;
          break;
        case 'selfie':
          selfieDocument = file;
          break;
      }
    });
  }

  bool _documentsValid() {
    // Bicicleta e entrega a pé não precisam de CNH/CRLV.
    // Mesmo assim, mantemos documento de identificação + selfie
    // para que o cadastro possa passar pela análise da MotoGo.
    if (driverType == 'delivery_bicicleta') {
      // Mantém o comportamento já existente da bicicleta: cadastro
      // sem CNH, CRLV ou upload obrigatório de documentos.
      return true;
    }

    if (driverType == 'delivery_pedestre') {
      if (identificationDocument == null || selfieDocument == null) {
        _showMessage(
          'Envie seu documento de identificação e uma selfie para análise.',
          error: true,
        );
        return false;
      }
      return true;
    }

    if (identificationDocument == null ||
        cnhDocument == null ||
        vehicleDocument == null ||
        selfieDocument == null) {
      _showMessage(
        'Envie CNH, documento de identificação, documento do veículo e selfie.',
        error: true,
      );
      return false;
    }
    return true;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) return;

    if (!_documentsValid()) return;

    if (passwordController.text != confirmPasswordController.text) {
      _showMessage('As senhas não são iguais.', error: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await DriverService.registerDriver(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        city: cityController.text.trim(),
        state: stateController.text.trim().toUpperCase(),
        password: passwordController.text,
        cpf: cpfController.text.trim(),
        birthDate: birthDateController.text.trim(),
        driverType: driverType,
        cnh: driverType == 'delivery_pedestre'
            ? ''
            : cnhController.text.trim(),
        cnhCategory: driverType == 'delivery_pedestre'
            ? ''
            : cnhCategory,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final driverId = int.tryParse(
          result['driver_id']?.toString() ?? '',
        );

        if (driverId != null && driverType != 'delivery_bicicleta') {
          final documents = <String, PlatformFile>{};

          if (driverType == 'delivery_pedestre') {
            documents['identification_document'] = identificationDocument!;
            documents['selfie'] = selfieDocument!;
          } else {
            documents['identification_document'] = identificationDocument!;
            documents['cnh_document'] = cnhDocument!;
            documents['vehicle_document'] = vehicleDocument!;
            documents['selfie'] = selfieDocument!;
          }

          final upload = await DriverService.uploadDocuments(
            driverId: driverId,
            documents: documents,
          );

          if (upload['success'] != true) {
            _showMessage(
              upload['message']?.toString() ??
                  'Cadastro criado, mas os documentos não foram enviados.',
              error: true,
            );
            return;
          }
        }

        _showMessage(
          result['message'] ??
              'Cadastro realizado com sucesso. Aguarde a aprovação.',
        );

        await Future.delayed(const Duration(milliseconds: 1200));

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        _showMessage(
          result['message'] ?? 'Não foi possível realizar o cadastro.',
          error: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Não foi possível conectar ao servidor.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selected == null) return;

    final day = selected.day.toString().padLeft(2, '0');
    final month = selected.month.toString().padLeft(2, '0');

    setState(() {
      birthDateController.text =
          '$day/$month/${selected.year}';
    });
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Cadastro de motorista'),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),

                _sectionTitle(
                  'Dados pessoais',
                  'Informe seus dados para criar sua conta.',
                ),
                const SizedBox(height: 16),

                _input(
                  controller: nameController,
                  label: 'Nome completo',
                  hint: 'Digite seu nome',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Digite seu nome completo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _input(
                  controller: emailController,
                  label: 'E-mail',
                  hint: 'seuemail@email.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite seu e-mail.';
                    }
                    if (!value.contains('@')) {
                      return 'Digite um e-mail válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _input(
                  controller: phoneController,
                  label: 'Telefone',
                  hint: '(32) 99999-9999',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().length < 8) {
                      return 'Digite um telefone válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                if (citiesLoading)
                  InputDecorator(
                    decoration: _inputDecoration(
                      label: 'Cidade onde irá trabalhar',
                      hint: 'Carregando cidades atendidas...',
                      icon: Icons.location_city_outlined,
                    ),
                    child: const SizedBox(
                      height: 20,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                else if (serviceCities.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: cityController.text.isEmpty
                        ? null
                        : serviceCities.any((item) =>
                                item['city'] == cityController.text &&
                                item['state'] == stateController.text)
                            ? '${cityController.text}|${stateController.text}'
                            : null,
                    decoration: _inputDecoration(
                      label: 'Cidade onde irá trabalhar',
                      hint: 'Selecione a cidade',
                      icon: Icons.location_city_outlined,
                    ),
                    items: serviceCities.map((item) {
                      final city = item['city']!;
                      final state = item['state']!;
                      return DropdownMenuItem<String>(
                        value: '$city|$state',
                        child: Text('$city - $state'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final parts = value.split('|');
                      if (parts.length != 2) return;
                      setState(() {
                        cityController.text = parts[0];
                        stateController.text = parts[1];
                      });
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecione sua cidade de operação.'
                        : null,
                  )
                else
                  _input(
                    controller: cityController,
                    label: 'Cidade onde irá trabalhar',
                    hint: 'Ex.: Tiradentes',
                    icon: Icons.location_city_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Digite sua cidade de operação.';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),

                if (serviceCities.isNotEmpty)
                  TextFormField(
                    controller: stateController,
                    readOnly: true,
                    decoration: _inputDecoration(
                      label: 'Estado',
                      hint: 'Estado da cidade selecionada',
                      icon: Icons.map_outlined,
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecione sua cidade.'
                        : null,
                  )
                else
                  DropdownButtonFormField<String>(
                    value: stateController.text.isEmpty ? null : stateController.text,
                    decoration: _inputDecoration(
                      label: 'Estado',
                      hint: 'Selecione a UF',
                      icon: Icons.map_outlined,
                    ),
                    items: const [
                      'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
                      'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
                    ].map((uf) => DropdownMenuItem<String>(
                      value: uf,
                      child: Text(uf),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => stateController.text = value);
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecione seu estado.'
                        : null,
                  ),
                const SizedBox(height: 14),

                _input(
                  controller: cpfController,
                  label: 'CPF',
                  hint: '000.000.000-00',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().length < 11) {
                      return 'Digite um CPF válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: birthDateController,
                  readOnly: true,
                  onTap: _selectBirthDate,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecione sua data de nascimento.';
                    }
                    return null;
                  },
                  decoration: _inputDecoration(
                    label: 'Data de nascimento',
                    hint: 'DD/MM/AAAA',
                    icon: Icons.calendar_month_outlined,
                    suffixIcon:
                        const Icon(Icons.keyboard_arrow_down),
                  ),
                ),

                const SizedBox(height: 30),

                _sectionTitle(
                  'Tipo de serviço',
                  'Escolha como você pretende trabalhar.',
                ),
                const SizedBox(height: 16),
                _buildDriverTypes(),

                const SizedBox(height: 20),

                if (driverType != 'delivery_bicicleta' &&
                    driverType != 'delivery_pedestre') ...[
                  _sectionTitle(
                    'Dados da habilitação',
                    'Informe os dados da sua CNH.',
                  ),
                  const SizedBox(height: 16),

                  _input(
                    controller: cnhController,
                    label: 'Número da CNH',
                    hint: 'Digite o número da CNH',
                    icon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (driverType == 'delivery_bicicleta') return null;
                      if (value == null || value.trim().length < 5) {
                        return 'Digite o número da CNH.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    'Categoria da CNH',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCnhCategories(),
                  const SizedBox(height: 30),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(.08),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.green.withOpacity(.18)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          driverType == 'delivery_pedestre'
                              ? Icons.directions_walk
                              : Icons.pedal_bike,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            driverType == 'delivery_pedestre'
                                ? 'Cadastro para entrega a pé: não é necessário possuir CNH nem veículo. Envie documento de identificação e selfie para análise da equipe MotoGo.'
                                : 'Cadastro para bicicleta: não é necessário possuir CNH nem documento de veículo. Você poderá concluir o cadastro sem esses documentos.',
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                _sectionTitle(
                  'Documentos',
                  (driverType == 'delivery_bicicleta' ||
                          driverType == 'delivery_pedestre')
                      ? 'CNH e documento de veículo não são necessários para este tipo de entrega.'
                      : 'Envie os documentos para análise da equipe MotoGo.',
                ),
                const SizedBox(height: 15),

                if (driverType == 'delivery_pedestre') ...[
                  _documentPickerTile(
                    icon: Icons.description_outlined,
                    title: 'Documento de identificação',
                    file: identificationDocument,
                    onTap: () => _pickDocument('identification_document'),
                  ),
                  const SizedBox(height: 10),
                  _documentPickerTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Selfie',
                    file: selfieDocument,
                    onTap: () => _pickDocument('selfie'),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Para entrega a pé, CNH e documento de veículo não são necessários. Documento de identificação e selfie são obrigatórios para análise.',
                            style: TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (driverType == 'delivery_bicicleta')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Para bicicleta, CNH e documento do veículo não são obrigatórios.',
                            style: TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _documentPickerTile(
                    icon: Icons.description_outlined,
                    title: 'Documento de identificação',
                    file: identificationDocument,
                    onTap: () => _pickDocument('identification_document'),
                  ),
                  const SizedBox(height: 10),
                  _documentPickerTile(
                    icon: Icons.credit_card_outlined,
                    title: 'CNH',
                    file: cnhDocument,
                    onTap: () => _pickDocument('cnh_document'),
                  ),
                  const SizedBox(height: 10),
                  _documentPickerTile(
                    icon: Icons.directions_car_outlined,
                    title: 'Documento do veículo (CRLV)',
                    file: vehicleDocument,
                    onTap: () => _pickDocument('vehicle_document'),
                  ),
                  const SizedBox(height: 10),
                  _documentPickerTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Selfie',
                    file: selfieDocument,
                    onTap: () => _pickDocument('selfie'),
                  ),
                ],

                const SizedBox(height: 30),

                _sectionTitle(
                  'Segurança',
                  'Crie uma senha para acessar sua conta.',
                ),
                const SizedBox(height: 16),

                _input(
                  controller: passwordController,
                  label: 'Senha',
                  hint: 'Mínimo de 6 caracteres',
                  icon: Icons.lock_outline,
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'A senha precisa ter pelo menos 6 caracteres.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                _input(
                  controller: confirmPasswordController,
                  label: 'Confirmar senha',
                  hint: 'Digite a senha novamente',
                  icon: Icons.lock_reset_outlined,
                  obscureText: obscureConfirmPassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword =
                            !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme sua senha.';
                    }
                    if (value != passwordController.text) {
                      return 'As senhas não coincidem.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                _buildVerificationInfo(),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Criar conta de motorista',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Já possui uma conta?',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withOpacity(.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.two_wheeler,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seja um motorista MotoGo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Cadastre seus dados e aguarde a aprovação.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverTypes() {
    return Column(
      children: driverTypes.map((item) {
        final selected = driverType == item['value'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              setState(() {
                driverType = item['value'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : Colors.grey.shade200,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: selected
                          ? AppColors.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCnhCategories() {
    const categories = ['A', 'B', 'AB', 'C', 'D', 'E'];

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: categories.map((category) {
        final selected = cnhCategory == category;

        return ChoiceChip(
          label: Text(category),
          selected: selected,
          onSelected: (_) {
            setState(() {
              cnhCategory = category;
            });
          },
          selectedColor: AppColors.primary.withOpacity(.15),
          labelStyle: TextStyle(
            color: selected
                ? AppColors.primary
                : Colors.black87,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _documentPickerTile({
    required IconData icon,
    required String title,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final selected = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? Colors.green.withOpacity(.06) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? Colors.green.withOpacity(.35) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.green.withOpacity(.10)
                    : AppColors.primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                selected ? Icons.check_circle_outline : icon,
                color: selected ? Colors.green : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    selected ? file.name : 'Toque para selecionar foto ou PDF',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? Colors.green.shade700 : Colors.grey.shade600, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.attach_file, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _documentPlaceholder(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.add_circle_outline,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.orange.withOpacity(.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.orange,
            size: 23,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Após o cadastro, seus dados serão enviados para análise. Enquanto estiver pendente, você não poderá receber corridas.',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      validator: validator,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }
}
