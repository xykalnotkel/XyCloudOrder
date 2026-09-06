import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../../core/motion.dart';
import '../widgets/brand_logos.dart';
import '../widgets/common.dart';
import 'lupa_password_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.modeDaftar = false});
  final bool modeDaftar;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();

  late bool daftar = widget.modeDaftar;
  bool lihat = false;
  bool ingat = true;
  String? _galat;

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
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final s = context.read<AppState>();
    final email = _email.text.trim();
    if (ingat) await Prefs.simpanEmail(email);

    if (daftar) {
      final hasil = await s.daftar(
        nama: _nama.text.trim(),
        email: email,
        password: _pass.text,
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      if (hasil == null) {
        setState(() => _galat = s.error ?? 'Pendaftaran gagal, coba lagi.');
        return;
      }
      Navigator.push(
        context,
        xyRoute(OtpScreen(
          email: '${hasil['email'] ?? email}',
          nama: _nama.text.trim(),
          pesanAwal: '${hasil['pesan'] ?? ''}',
        )),
      );
      return;
    }

    final ok = await s.login(email, _pass.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil masuk. Selamat datang kembali.')),
      );
      return;
    }

    // akun ada tetapi email belum diverifikasi
    if (s.emailMenungguVerifikasi != null) {
      final tujuan = s.emailMenungguVerifikasi!;
      s.emailMenungguVerifikasi = null;
      Navigator.push(
        context,
        xyRoute(OtpScreen(email: tujuan, pesanAwal: s.error)),
      );
      return;
    }

    setState(() => _galat = s.error ?? 'Terjadi kesalahan, coba lagi.');
  }

  void _gantiMode() {
    setState(() {
      daftar = !daftar;
      _galat = null;
      _form.currentState?.reset();
    });
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

                    const SizedBox(height: 26),
                    FadeInUp(
                      child: Row(children: [
                        const XyLogo(size: 52, radius: 17),
                        const SizedBox(width: 13),
                        const XyWordmark(tinggi: 24),
                      ]),
                    ),
                    const SizedBox(height: 22),

                    FadeInUp(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        daftar ? 'Buat akun baru' : 'Selamat datang kembali',
                        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInUp(
                      delay: const Duration(milliseconds: 140),
                      child: Text(
                        daftar
                            ? 'Daftar gratis. Kami kirim kode verifikasi ke emailmu, jadi pastikan emailnya aktif.'
                            : 'Masuk untuk melanjutkan sewa PC, membeli akun, dan memantau order kamu.',
                        style: const TextStyle(color: XyTheme.muted, fontSize: 14, height: 1.6),
                      ),
                    ),

                    const SizedBox(height: 26),

                    if (_galat != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                        decoration: BoxDecoration(
                          color: XyTheme.danger.withOpacity(.07),
                          borderRadius: BorderRadius.circular(XyRadius.sm),
                          border: Border.all(color: XyTheme.danger.withOpacity(.22)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: XyTheme.danger, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _galat!,
                              style: const TextStyle(color: XyTheme.danger, fontSize: 12.8, fontWeight: FontWeight.w600, height: 1.4),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                    ],

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
                      const _Label('Nomor WhatsApp'),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Nomor WhatsApp wajib diisi';
                            if (t.length < 9) return 'Nomor belum lengkap';
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: '08xxxxxxxxxx',
                            prefixIcon: Icon(Icons.phone_iphone_rounded),
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
                          onPressed: () => Navigator.push(
                            context,
                            xyRoute(LupaPasswordScreen(emailAwal: _email.text.trim())),
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
                        onTap: _gantiMode,
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
