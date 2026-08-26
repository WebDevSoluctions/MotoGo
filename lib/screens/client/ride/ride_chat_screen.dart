import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/colors.dart';
import '../../../services/api_service.dart';

class RideChatScreen extends StatefulWidget {
  final int rideId;
  final int userId;
  final String driverName;
  final bool isDriver;

  const RideChatScreen({
    super.key,
    required this.rideId,
    required this.userId,
    required this.driverName,
    this.isDriver = false,
  });

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final result = await ApiService.getRideChat(userId: widget.userId, rideId: widget.rideId);
    if (!mounted) return;
    if (result['success'] == true) {
      final list = result['messages'] is List ? List<dynamic>.from(result['messages']) : <dynamic>[];
      final changed = list.length != _messages.length;
      setState(() {
        _messages = list;
        _loading = false;
      });
      if (changed) _scrollToBottom();
    } else if (!silent) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível carregar o chat.')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await ApiService.sendRideChat(userId: widget.userId, rideId: widget.rideId, message: message);
    if (!mounted) return;
    setState(() => _sending = false);
    if (result['success'] == true) {
      _controller.clear();
      await _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Não foi possível enviar a mensagem.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDriver ? 'Chat com passageiro' : 'Chat com ${widget.driverName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Nenhuma mensagem ainda.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, index) {
                          final m = _messages[index] as Map;
                          final mine = m['sender_user_id']?.toString() == widget.userId.toString();
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: mine ? AppColors.primary : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                m['message']?.toString() ?? '',
                                style: TextStyle(color: mine ? Colors.white : Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Digite uma mensagem...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
