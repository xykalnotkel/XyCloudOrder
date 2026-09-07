import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'otp_screen.dart';

/// Minta kode reset password lewat email.
class LupaPasswordScreen extends StatefulWidget {
  const LupaPasswordScreen({super.key, this.emailAwal = ''});
  final String emailAwal;

  @override
  State<LupaPasswordScreen> createState() => _LupaPasswordScreenState();
}

class _LupaPasswordScreenState extends State<LupaPasswordScreen> {
  late final _email = TextEditingController(text: widget.emailAwal);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final s = context.read<AppState>();
    final email = _email.text.trim();
    final pesan = await s.lupaPassword(email);
    if (!mounted) return;
    if (pesan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.error ?? 'Gagal mengirim kode.')),
      );
      return;
    }
    Navigator.push(
      context,
      xyRoute(OtpScreen(email: email, mode: 'reset', pesanAwal: pesan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppState>().loading;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
            children: [
              if (Navigator.canPop(context))
                Pressable(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: XyTheme.of(context).surface,
                      borderRadius: BorderRadius.circular(XyRadius.sm),
                      border: Border.all(color: XyTheme.of(context).line),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),

              const SizedBox(height: 22),
              const Center(child: XyIlustrasi('cs', tinggi: 168)),
              const SizedBox(height: 14),

              const Text(
                'Lupa password',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.2),
              ),
              const SizedBox(height: 8),
               Text(
                'Masukkan email akunmu. Kami kirim kode 6 digit untuk membuat password baru.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 14, height: 1.6),
              ),

              const SizedBox(height: 26),
              Form(
                key: _form,
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Format email belum benar' : null,
                  decoration: const InputDecoration(
                    hintText: 'nama@email.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              GradientButton(
                label: 'Kirim Kode Reset',
                icon: Icons.send_rounded,
                loading: loading,
                onPressed: _kirim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
