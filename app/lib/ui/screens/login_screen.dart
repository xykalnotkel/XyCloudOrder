import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/brand_logos.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.modeDaftar = false});
  final bool modeDaftar;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nama = TextEditingController();
  final _email = TextEditingController(text: 'rangga@xycloud.id');
  final _pass = TextEditingController(text: 'xycloud123');
  final _form = GlobalKey<FormState>();

  late bool daftar = widget.modeDaftar;
  bool lihat = false;
  bool ingat = true;

  @override
  void initState() {
    super.initState();
    Prefs.emailTerakhir().then((e) {
      if (e != null && mounted) _email.text = e;
    });
  }

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final s = context.read<AppState>();
    if (ingat) await Prefs.simpanEmail(_email.text.trim());
    final ok = await s.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (ok) {
      // kembalikan stack ke root supaya shell aplikasi tampil
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.error ?? 'Gagal masuk, coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppState>().loading;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ---- back ----
                    if (Navigator.canPop(context))
                      Pressable(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: XyTheme.surface,
                            borderRadius: BorderRadius.circular(XyRadius.sm),
                            border: Border.all(color: XyTheme.line),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),

                    const SizedBox(height: 28),
                    FadeInUp(child: const XyLogo(size: 58, radius: 20)),
                    const SizedBox(height: 24),

                    FadeInUp(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        daftar ? 'Buat akun XyCloud' : 'Selamat datang kembali',
                        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInUp(
                      delay: const Duration(milliseconds: 140),
                      child: Text(
                        daftar
                            ? 'Daftar gratis, langsung dapat saldo percobaan untuk mencoba sewa PC.'
                            : 'Masuk untuk melanjutkan sewa PC, membeli akun, dan memantau order kamu.',
                        style: const TextStyle(color: XyTheme.muted, fontSize: 14, height: 1.6),
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (daftar) ...[
                      const _Label('Nama Lengkap'),
                      FadeInUp(
                        delay: const Duration(milliseconds: 180),
                        child: TextFormField(
                          controller: _nama,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Nama minimal 3 karakter' : null,
                          decoration: const InputDecoration(
                            hintText: 'Nama kamu',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    const _Label('Email'),
                    FadeInUp(
                      delay: const Duration(milliseconds: 220),
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Format email belum benar' : null,
                        decoration: const InputDecoration(
                          hintText: 'nama@email.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    const _Label('Password'),
                    FadeInUp(
                      delay: const Duration(milliseconds: 280),
                      child: TextFormField(
                        controller: _pass,
                        obscureText: !lihat,
                        validator: (v) => (v == null || v.length < 6) ? 'Password minimal 6 karakter' : null,
                        decoration: InputDecoration(
                          hintText: 'Masukkan password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => lihat = !lihat),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Row(children: [
                      SizedBox(
                        width: 34,
                        child: Checkbox(
                          value: ingat,
                          onChanged: (v) => setState(() => ingat = v ?? true),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          side: const BorderSide(color: XyTheme.line, width: 1.6),
                          activeColor: XyTheme.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Text('Ingat saya', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (!daftar)
                        TextButton(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tautan reset dikirim ke email kamu.')),
                          ),
                          child: const Text('Lupa password?'),
                        ),
                    ]),

                    const SizedBox(height: 18),
                    FadeInUp(
                      delay: const Duration(milliseconds: 340),
                      child: GradientButton(
                        label: daftar ? 'Daftar Sekarang' : 'Masuk',
                        icon: daftar ? Icons.person_add_alt_rounded : Icons.arrow_forward_rounded,
                        loading: loading,
                        onPressed: _submit,
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('atau lanjut dengan',
                            style: TextStyle(color: XyTheme.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 20),

                    Row(children: [
                      Expanded(
                        child: _SosialBtn(
                          logo: const GoogleLogo(size: 21),
                          label: 'Google',
                          onTap: _submit,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SosialBtn(
                          logo: const FacebookLogo(size: 22),
                          label: 'Facebook',
                          onTap: _submit,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),
                    Center(
                      child: Pressable(
                        onTap: () => setState(() => daftar = !daftar),
                        scale: .98,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: XyTheme.muted, fontSize: 13.5, fontWeight: FontWeight.w500),
                              children: [
                                TextSpan(text: daftar ? 'Sudah punya akun?  ' : 'Belum punya akun?  '),
                                TextSpan(
                                  text: daftar ? 'Masuk' : 'Daftar gratis',
                                  style: const TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.teks);
  final String teks;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9, left: 2),
        child: Text(teks, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: -.1)),
      );
}

class _SosialBtn extends StatelessWidget {
  const _SosialBtn({required this.logo, required this.label, required this.onTap});
  final Widget logo;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: XyTheme.surface,
          borderRadius: BorderRadius.circular(XyRadius.md),
          border: Border.all(color: XyTheme.line),
          boxShadow: XyTheme.shadowXs,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          logo,
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8)),
        ]),
      ),
    );
  }
}
