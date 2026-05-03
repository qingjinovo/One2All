import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/signaling_service.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isWaiting = false;
  String? _myPairCode;
  Timer? _timeoutTimer;

  late final SignalingService _signaling;

  @override
  void initState() {
    super.initState();
    _signaling = context.read<SignalingService>();

    _signaling.addPairRequestListener(_onPairRequest);
    _signaling.addPairResponseListener(_onPairResponse);
    _signaling.addPairCodeAssignedListener(_onPairCodeAssigned);
  }

  void _onPairRequest(String senderId, String senderName) {
    if (mounted) {
      _showPairRequestDialog(senderId, senderName);
    }
  }

  void _onPairResponse(String senderId, bool accepted) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    _cancelTimeout();
    setState(() => _isWaiting = false);
    if (accepted) {
      _signaling.notifyPairAccepted(senderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pairingSuccessful)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pairingRequestDeclined)),
      );
    }
  }

  void _onPairCodeAssigned(String pairCode) {
    if (mounted) {
      setState(() => _myPairCode = pairCode);
    }
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pairDevice),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.link,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.connectNewDevice,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.pairingInstructions,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_myPairCode != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        l10n.myPairingCode,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _myPairCode!,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: l10n.pairingCode,
                hintText: l10n.enter6DigitCode,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              maxLength: 6,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isWaiting ? null : _sendPairRequest,
              icon: const Icon(Icons.send),
              label: Text(l10n.sendPairRequest),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              l10n.orWaitForRequest,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isWaiting)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(l10n.waitingForPairing),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _startListening,
                icon: const Icon(Icons.wifi_tethering),
                label: Text(l10n.startListening),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _sendPairRequest() {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseEnter6DigitCode)),
      );
      return;
    }

    _signaling.sendPairRequest(
      receiverId: code,
      senderName: l10n.myDevice,
    );

    setState(() => _isWaiting = true);

    _cancelTimeout();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() => _isWaiting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pairingRequestTimedOut)),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.pairRequestSent)),
    );
  }

  void _startListening() {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isWaiting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.listeningForPairing)),
    );
  }

  void _showPairRequestDialog(String senderId, String senderName) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pairingRequest),
        content: Text(l10n.deviceWantsToPair(senderName)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToPair(senderId, false);
            },
            child: Text(l10n.decline),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToPair(senderId, true);
            },
            child: Text(l10n.accept),
          ),
        ],
      ),
    );
  }

  void _respondToPair(String senderId, bool accepted) {
    final l10n = AppLocalizations.of(context)!;
    _signaling.sendPairResponse(
      receiverId: senderId,
      accepted: accepted,
    );

    setState(() {
      _isWaiting = false;
    });

    if (accepted) {
      _signaling.notifyPairAccepted(senderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pairingSuccessful)),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _cancelTimeout();
    _signaling.removePairRequestListener(_onPairRequest);
    _signaling.removePairResponseListener(_onPairResponse);
    _signaling.removePairCodeAssignedListener(_onPairCodeAssigned);
    _codeController.dispose();
    super.dispose();
  }
}
