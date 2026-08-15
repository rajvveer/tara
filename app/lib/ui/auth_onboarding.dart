// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../app_scope.dart';
import '../data/api.dart';
import '../data/realtime.dart';
import '../data/social_auth.dart';
import 'avatar.dart';
import 'theme.dart';
import 'widgets.dart';

enum AuthMode { login, register }

class AuthLanding extends StatelessWidget {
  const AuthLanding({super.key});

  void _open(BuildContext context, AuthMode mode) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => AuthScreen(mode: mode)));

  @override
  Widget build(BuildContext context) => _JourneyHeroArtwork(
    onGetStarted: () => _open(context, AuthMode.register),
    onSignIn: () => _open(context, AuthMode.login),
    onPreview: context.appRead.exploreDemo,
  );
}

class _JourneyHeroArtwork extends StatelessWidget {
  const _JourneyHeroArtwork({
    required this.onGetStarted,
    required this.onSignIn,
    required this.onPreview,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final systemUi = onwardSystemUiOverlayStyle(dark: false).copyWith(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUi,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(
              key: const ValueKey('landing-progress-artwork'),
              child: Semantics(
                label: 'A calm path of small steps leading toward a new day',
                image: true,
                child: Image.asset(
                  'assets/illustrations/landing-journey-v1.png',
                  key: const ValueKey('landing-journey-image'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x060E0721),
                    Color(0x160E0721),
                    Color(0xC915062B),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            SafeArea(
              child: ContentWidth(
                maxWidth: 560,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 30,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: OnwardWordmark(compact: true),
                            ),
                            const Spacer(),
                            Text(
                              'Less planning.\nMore progress.',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 34,
                                    height: 1.02,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Build a rhythm that fits real life, one small win at a time.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: .84),
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                key: const ValueKey('landing-hero-get-started'),
                                onPressed: onGetStarted,
                                style: FilledButton.styleFrom(
                                  backgroundColor: OnwardColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Get started'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: onSignIn,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFF202846),
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: .48),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Sign in'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: onPreview,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(
                                  alpha: .9,
                                ),
                              ),
                              child: const Text('Preview the app'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableNeumorphic extends StatefulWidget {
  const _PressableNeumorphic({
    required this.child,
    this.enabled = true,
    this.color,
  });

  final Widget child;
  final bool enabled;
  final Color? color;

  @override
  State<_PressableNeumorphic> createState() => _PressableNeumorphicState();
}

class _PressableNeumorphicState extends State<_PressableNeumorphic> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(_PressableNeumorphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _setPressed(true),
    onPointerUp: (_) => _setPressed(false),
    onPointerCancel: (_) => _setPressed(false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 110),
      decoration: _pressed
          ? OnwardNeumorphism.pressed(
              context,
              color: widget.color,
              radius: OnwardNeumorphism.controlRadius,
              depth: .85,
            )
          : OnwardNeumorphism.raised(
              context,
              color: widget.color,
              radius: OnwardNeumorphism.controlRadius,
              depth: .85,
            ),
      child: widget.child,
    ),
  );
}

class _NeumorphicField extends StatelessWidget {
  const _NeumorphicField({
    required this.child,
    this.glass = false,
    this.flat = false,
  });

  final Widget child;
  final bool glass;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    );
    final flatBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );
    final themedChild = Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: flat,
          fillColor: flat
              ? theme.brightness == Brightness.dark
                    ? OnwardColors.darkElevated
                    : Colors.white
              : Colors.transparent,
          labelStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .5),
            fontSize: 14,
            height: 1.35,
            letterSpacing: 0,
          ),
          enabledBorder: flat ? flatBorder : border,
          disabledBorder: flat ? flatBorder : border,
          focusedBorder: flat
              ? flatBorder.copyWith(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.6,
                  ),
                )
              : null,
        ),
      ),
      child: child,
    );
    if (flat) return themedChild;
    if (glass) {
      return _OnboardingGlassSurface(
        radius: 16,
        tintOpacity: .32,
        borderOpacity: .82,
        showShadow: false,
        padding: EdgeInsets.zero,
        child: themedChild,
      );
    }
    return OnwardNeumorphicSurface(
      pressed: true,
      radius: 16,
      depth: .72,
      child: themedChild,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.mode});

  final AuthMode mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  bool get _register => widget.mode == AuthMode.register;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final state = context.appRead;
    final success = _register
        ? await state.register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          )
        : await state.login(email: _email.text, password: _password.text);
    if (success && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _social(SocialProvider provider) async {
    FocusScope.of(context).unfocus();
    final success = await context.appRead.socialLogin(provider);
    if (success && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? OnwardColors.darkCanvas
          : const Color(0xFFFDFCFB),
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: 480,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 56),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OnwardWordmark(compact: true),
                    const SizedBox(height: 16),
                    _AuthIntro(register: _register),
                    const SizedBox(height: 22),
                    if (state.message != null) ...[
                      ErrorNotice(
                        message: state.message!,
                        onDismiss: state.clearMessage,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_register) ...[
                      _NeumorphicField(
                        flat: true,
                        child: TextFormField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            hintText: 'How should we greet you?',
                          ),
                          validator: (value) =>
                              value == null || value.trim().length < 2
                              ? 'Enter your name.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _NeumorphicField(
                      flat: true,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return email.contains('@') && email.contains('.')
                              ? null
                              : 'Enter a valid email address.';
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _NeumorphicField(
                      flat: true,
                      child: TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Use at least 8 characters.'
                            : null,
                      ),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'At least 8 characters',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: .72),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showReset(context),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: state.busy ? null : _submit,
                        child: state.busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_register ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AuthDivider(
                      label: _register ? 'or sign up with' : 'or sign in with',
                    ),
                    const SizedBox(height: 20),
                    _SocialButton(
                      provider: SocialProvider.google,
                      mode: widget.mode,
                      busy: state.busy,
                      active: state.activeSocialProvider,
                      onPressed: () => _social(SocialProvider.google),
                    ),
                    const SizedBox(height: 10),
                    _SocialButton(
                      provider: SocialProvider.apple,
                      mode: widget.mode,
                      busy: state.busy,
                      active: state.activeSocialProvider,
                      onPressed: () => _social(SocialProvider.apple),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 20),
                      const _LegalAgreement(),
                    ],
                    const SizedBox(height: 24),
                    _AuthModeSwitch(register: _register, enabled: !state.busy),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReset(BuildContext context) async {
    final reset = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ResetPasswordSheet(
        initialEmail: _email.text,
        initialCode: context.appRead.developmentResetToken,
      ),
    );
    if (reset == true && context.mounted) {
      showToast(context, 'Password updated. Sign in with your new password.');
    }
  }
}

class _AuthIntro extends StatelessWidget {
  const _AuthIntro({required this.register});

  final bool register;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [OnwardColors.darkElevated, OnwardColors.darkCanvas]
            : const [Color(0xFFF8F4FF), Color(0xFFF0F5FF)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                register ? 'Create your account' : 'Welcome back',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                register
                    ? 'Start small, stay consistent, and watch your progress grow.'
                    : 'Your goals and next small steps are ready for you.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: onwardMuted(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Image.asset(
          'assets/illustrations/auth-progress.png',
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          alignment: Alignment.centerRight,
          semanticLabel: 'Stepping stones toward steady progress',
          filterQuality: FilterQuality.high,
        ),
      ],
    ),
  );
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: onwardMuted(context)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(1) >= 1.8 ||
            constraints.maxWidth < 320) {
          return labelWidget;
        }
        return Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: labelWidget,
            ),
            const Expanded(child: Divider()),
          ],
        );
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.mode,
    required this.busy,
    required this.active,
    required this.onPressed,
  });

  final SocialProvider provider;
  final AuthMode mode;
  final bool busy;
  final SocialProvider? active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final loading = busy && active == provider;
    final providerName = provider == SocialProvider.google ? 'Google' : 'Apple';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF2F2F4) : const Color(0xFF202124);
    final background = dark ? const Color(0xFF202126) : const Color(0xFFF9F9FC);
    return SizedBox(
      height: 52,
      child: FilledButton(
        key: ValueKey('social-${mode.name}-${provider.name}'),
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          foregroundColor: foreground,
          backgroundColor: background,
          disabledBackgroundColor: background.withValues(alpha: .68),
          disabledForegroundColor: foreground.withValues(alpha: .58),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: loading
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : provider == SocialProvider.google
                  ? const _GoogleMark()
                  : Icon(Icons.apple_rounded, size: 23, color: foreground),
            ),
            Positioned.fill(
              left: 34,
              right: 34,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${mode == AuthMode.register ? 'Sign up' : 'Continue'} with $providerName',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/auth/google_g.png',
    width: 20,
    height: 20,
    semanticLabel: 'Google',
    filterQuality: FilterQuality.high,
  );
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({required this.register, required this.enabled});

  final bool register;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: enabled
          ? () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => AuthScreen(
                  mode: register ? AuthMode.login : AuthMode.register,
                ),
              ),
            )
          : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(48, 44),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: register
                  ? 'Already have an account? '
                  : 'New to GoalSpring? ',
              style: TextStyle(color: onwardMuted(context)),
            ),
            TextSpan(
              text: register ? 'Sign in' : 'Create account',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _LegalAgreement extends StatelessWidget {
  const _LegalAgreement();

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .74),
      fontSize: 13,
      height: 1.5,
    ),
    textAlign: TextAlign.center,
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('By creating an account, you agree to the '),
        _LegalLink(
          label: 'Terms of use',
          title: 'TERMS OF USE — PRE-RELEASE SUMMARY',
          body:
              'GoalSpring is a planning and progress tool, not medical, mental-health, legal, or financial advice. Keep your account secure, use the service lawfully, and do not attempt to disrupt or misuse it. You remain responsible for the content you add. This pre-release software may change and may contain errors. Replace this summary with final published terms before public release.',
        ),
        const Text(' and acknowledge the '),
        _LegalLink(
          label: 'Privacy summary',
          title: 'PRIVACY — PRE-RELEASE SUMMARY',
          body:
              'GoalSpring stores the account information and goal data you provide so it can sync your plan. Passwords are hashed on the server. Session tokens are kept in secure device storage, and display data may be cached on your device for offline use. Google or Apple identity data is used to verify sign-in and create or link your account. You can export or permanently delete your account data in Settings. Replace this summary with a published privacy policy before public release.',
        ),
        const Text('.'),
      ],
    ),
  );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.title,
    required this.body,
  });

  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: label,
    child: TextButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => _LegalSheet(title: title, body: body),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(label),
    ),
  );
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: ContentWidth(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({required this.initialEmail, this.initialCode});

  final String initialEmail;
  final String? initialCode;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _code;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _completeReset;
  bool _instructionsSent = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
    _code = TextEditingController(text: widget.initialCode);
    _completeReset = widget.initialCode?.isNotEmpty == true;
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final state = context.appRead;
    final ok = await state.forgotPassword(_email.text);
    if (!ok || !mounted) return;
    setState(() {
      _instructionsSent = true;
      _completeReset = true;
      final token = state.developmentResetToken;
      if (token != null) _code.text = token;
    });
  }

  Future<void> _submitReset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.appRead.resetPassword(
      token: _code.text,
      newPassword: _password.text,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _showCodeEntry() {
    context.appRead.clearMessage();
    setState(() => _completeReset = true);
  }

  void _showRequest() {
    context.appRead.clearMessage();
    setState(() => _completeReset = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ContentWidth(
        maxWidth: 520,
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _completeReset
                      ? 'Choose a new password'
                      : 'Reset your password',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _completeReset
                      ? _instructionsSent
                            ? 'If that account exists, instructions are on their way. Paste the reset code below.'
                            : 'Paste the reset code from your password reset instructions.'
                      : 'We’ll send reset instructions if the address belongs to an account.',
                ),
                const SizedBox(height: 20),
                if (state.message != null) ...[
                  ErrorNotice(
                    message: state.message!,
                    onDismiss: state.clearMessage,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_completeReset) ...[
                  _NeumorphicField(
                    child: TextFormField(
                      controller: _code,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Reset code',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 32
                          ? 'Enter the complete reset code.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NeumorphicField(
                    child: TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NeumorphicField(
                    child: TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitReset(),
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (value) => value != _password.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                  ),
                ] else
                  _NeumorphicField(
                    child: TextFormField(
                      controller: _email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _requestReset(),
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return email.contains('@') && email.contains('.')
                            ? null
                            : 'Enter a valid email address.';
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                _PressableNeumorphic(
                  enabled: !state.busy,
                  color: Theme.of(context).colorScheme.primary,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                    ),
                    onPressed: state.busy
                        ? null
                        : _completeReset
                        ? _submitReset
                        : _requestReset,
                    child: state.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _completeReset
                                ? 'Update password'
                                : 'Send reset instructions',
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : _completeReset
                      ? _showRequest
                      : _showCodeEntry,
                  child: Text(
                    _completeReset
                        ? 'Request a new code'
                        : 'I have a reset code',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.realtime});

  final RealtimeClient? realtime;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _SetupMode { manual, aiVoice }

class _VoiceMessage {
  const _VoiceMessage({required this.assistant, required this.text});

  final bool assistant;
  final String text;
}

class _LiveVoiceSource extends StreamAudioSource {
  final List<Uint8List> _history = [];
  final Set<StreamController<List<int>>> _listeners = {};
  final Completer<void> _ended = Completer<void>();
  bool _closed = false;

  Future<void> get ended => _ended.future;

  void add(Uint8List bytes) {
    if (_closed || bytes.isEmpty) return;
    _history.add(bytes);
    for (final listener in _listeners.toList(growable: false)) {
      listener.add(bytes);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _ended.complete();
    for (final listener in _listeners.toList(growable: false)) {
      unawaited(listener.close());
    }
    _listeners.clear();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final controller = StreamController<List<int>>();
    for (final chunk in _history) {
      controller.add(chunk);
    }
    if (_closed) {
      unawaited(controller.close());
    } else {
      _listeners.add(controller);
      controller.onCancel = () => _listeners.remove(controller);
    }
    return StreamAudioResponse(
      rangeRequestsSupported: false,
      sourceLength: null,
      contentLength: null,
      offset: null,
      stream: controller.stream,
      contentType: 'audio/mpeg',
    );
  }
}

class _MemoryVoiceSource extends StreamAudioSource {
  _MemoryVoiceSource(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: start == null ? null : bytes.length,
      contentLength: to - from,
      offset: start,
      stream: Stream<List<int>>.value(bytes.sublist(from, to)),
      contentType: contentType,
    );
  }
}

enum _MouthShape { closed, small, open, wide, round, teeth }

_MouthShape _mouthShapeFor(String text, double progress, {int? cueCount}) {
  if (text.isEmpty) return _MouthShape.small;
  final sounds = text
      .toLowerCase()
      .runes
      .where((sound) => !' \n\t.,!?;:।॥—-'.runes.contains(sound))
      .toList(growable: false);
  if (sounds.isEmpty) return _MouthShape.closed;
  final cues = math.min(sounds.length, math.max(1, cueCount ?? sounds.length));
  final cue = (progress.clamp(0.0, .9999) * cues).floor();
  final index = math.min(
    sounds.length - 1,
    (((cue + .5) / cues) * sounds.length).floor(),
  );
  final sound = String.fromCharCode(sounds[index]);
  if ('mbpfvपफबभमवপফবভমવપફબભਮਪਫਬਭਮபமவపఫబభమవಪಫಬಭಮವപഫബഭമവପଫବଭମ'.contains(sound)) {
    return _MouthShape.closed;
  }
  if ('ouqwऊउूुोौওউঊুূোৌઓઉઊુૂોૌਓਉਊੁੂੋੌஒஉஊுூொோௌఒఉఊుూొోౌಒಉಊುೂೊೋೌഒഉഊുൂൊോൌଓଉଊୁୂୋୌ'
      .contains(sound)) {
    return _MouthShape.round;
  }
  if ('eiyईइीिेैএইঈিীেৈએઇઈિીેૈਏਇਈਿੀੇੈஎஇஈிீெேைఎఇఈిీెేైಎಇಈಿೀೆೇೈഎഇഈിീെേൈଏଇଈିୀେୈ'
      .contains(sound)) {
    return _MouthShape.wide;
  }
  if ('aअआाঅআাઅઆાਅਆਾஅஆாఅఆాಅಆಾഅആാଅଆା'.contains(sound)) {
    return _MouthShape.open;
  }
  if ('fstzथतदधसशषফভથતદધસશષਥਤਦਧਸਸ਼ஷஸதசథతదధసశಷಥತದಧಸശസതദധശଷଥତଦଧସଶ'.contains(
    sound,
  )) {
    return _MouthShape.teeth;
  }
  return _MouthShape.small;
}

double _speechEnergy(List<double> envelope, double progress) {
  if (envelope.isEmpty) return .55;
  final position = progress.clamp(0.0, 1.0) * (envelope.length - 1);
  final left = position.floor();
  final right = math.min(left + 1, envelope.length - 1);
  return envelope[left] +
      (envelope[right] - envelope[left]) * (position - left);
}

({List<double> envelope, Duration duration}) _wavLipTrack(Uint8List audio) {
  if (audio.length < 44) return (envelope: const [], duration: Duration.zero);
  final data = ByteData.sublistView(audio);
  var channels = 1;
  var sampleRate = 24000;
  var bitsPerSample = 16;
  var dataStart = -1;
  var dataLength = 0;
  var offset = 12;
  while (offset + 8 <= audio.length) {
    final id = String.fromCharCodes(audio.sublist(offset, offset + 4));
    final length = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;
    if (chunkStart + length > audio.length) break;
    if (id == 'fmt ' && length >= 16) {
      channels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
    } else if (id == 'data') {
      dataStart = chunkStart;
      dataLength = length;
      break;
    }
    offset = chunkStart + length + (length.isOdd ? 1 : 0);
  }
  if (dataStart < 0 || bitsPerSample != 16 || channels < 1 || sampleRate < 1) {
    return (envelope: const [], duration: Duration.zero);
  }

  final blockAlign = channels * 2;
  final samplesPerFrame = math.max(1, sampleRate ~/ 30);
  final frameBytes = samplesPerFrame * blockAlign;
  final end = math.min(dataStart + dataLength, audio.length);
  final raw = <double>[];
  for (var frame = dataStart; frame < end; frame += frameBytes) {
    final frameEnd = math.min(frame + frameBytes, end);
    var sum = 0.0;
    var count = 0;
    for (var sample = frame; sample + 1 < frameEnd; sample += blockAlign) {
      final value = data.getInt16(sample, Endian.little) / 32768.0;
      sum += value * value;
      count++;
    }
    raw.add(count == 0 ? 0 : math.sqrt(sum / count));
  }
  final peak = raw.fold(0.0, math.max);
  if (peak == 0) return (envelope: raw, duration: Duration.zero);
  final floor = peak * .07;
  final range = math.max(.001, peak - floor);
  final envelope = [
    for (var index = 0; index < raw.length; index++)
      (((index > 0 ? raw[index - 1] : raw[index]) +
                      raw[index] * 2 +
                      (index + 1 < raw.length ? raw[index + 1] : raw[index])) /
                  4 -
              floor) /
          range,
  ].map((value) => value.clamp(0.0, 1.0)).toList(growable: false);
  final duration = Duration(
    microseconds:
        dataLength *
        Duration.microsecondsPerSecond ~/
        (sampleRate * blockAlign),
  );
  return (envelope: envelope, duration: duration);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _name;
  late final TextEditingController _profileImageUrl;
  final _objective = TextEditingController();
  final _constraints = TextEditingController();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  int _step = 0;
  final Set<String> _days = {'Mon', 'Wed', 'Fri'};
  String _time = 'Evening';
  String _frequency = '3 times a week';
  String _progress = 'Gentle';
  String _avatarKey = defaultOnwardAvatar;
  String _avatarSection = 'Head';
  bool _scheduleExpanded = false;
  _SetupMode? _setupMode;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  late final RealtimeClient _realtime;
  StreamSubscription<Uint8List>? _recordingSubscription;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  StreamSubscription<PlayerState>? _playerSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Timer? _recordingTimer;
  Timer? _typewriterTimer;
  _LiveVoiceSource? _liveVoiceSource;
  BytesBuilder _recordingBytes = BytesBuilder(copy: false);
  DateTime? _recordingStartedAt;
  DateTime? _lastSpeechAt;
  bool _heardSpeech = false;
  final List<_VoiceMessage> _voiceMessages = [];
  final Map<String, dynamic> _voiceAnswers = {};
  String? _voiceError;
  bool _voiceBusy = false;
  bool _recording = false;
  bool _voiceSpeaking = false;
  bool _voiceComplete = false;
  final ValueNotifier<double> _voiceProgress = ValueNotifier(0);
  Duration _voiceDuration = Duration.zero;
  String _voiceSpeechText = '';
  List<double> _voiceEnvelope = const [];
  List<String> _voiceGlyphs = const [];
  int _visibleVoiceGlyphs = 0;
  bool _typewriterStarted = false;

  static const _dayOptions = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _timeOptions = ['Morning', 'Afternoon', 'Evening', 'Flexible'];

  int get _visibleStep =>
      _setupMode == _SetupMode.aiVoice && _step == 4 ? 4 : _step + 1;
  int get _visibleStepCount => _setupMode == _SetupMode.aiVoice ? 4 : 5;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.appRead.user?.name ?? '');
    _profileImageUrl = TextEditingController(
      text: context.appRead.user?.profileImageUrl ?? '',
    );
    _avatarKey = normalizeOnwardAvatar(context.appRead.user?.avatarKey);
    _realtime = widget.realtime ?? RealtimeClient(context.appRead.api);
    _realtimeSubscription = _realtime.events.listen(_handleRealtimeEvent);
    if (_name.text.trim().length >= 2) {
      _voiceAnswers['name'] = _name.text.trim();
    }
    _playerSubscription = _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final speaking =
          state.playing && state.processingState == ProcessingState.ready;
      if (_voiceSpeaking != speaking) {
        setState(() {
          _voiceSpeaking = speaking;
          _voiceBusy = !speaking;
        });
      }
      if (speaking) _startTypewriter();
      if (state.processingState == ProcessingState.completed) {
        _completeTypewriter();
      }
    });
    _durationSubscription = _voicePlayer.durationStream.listen((duration) {
      if (duration != null) _voiceDuration = duration;
    });
    _positionSubscription = _voicePlayer.positionStream.listen((position) {
      final total = _voiceDuration.inMicroseconds;
      if (total > 0) {
        _voiceProgress.value = (position.inMicroseconds / total).clamp(
          0.0,
          1.0,
        );
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _profileImageUrl.dispose();
    _objective.dispose();
    _constraints.dispose();
    _recordingTimer?.cancel();
    _typewriterTimer?.cancel();
    unawaited(_liveVoiceSource?.close());
    _recordingSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _playerSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _voiceProgress.dispose();
    _recorder.dispose();
    _voicePlayer.dispose();
    unawaited(_realtime.dispose());
    super.dispose();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      showToast(context, 'Choose manual setup or AI voice setup.');
      return;
    }
    if (_step == 2 && _setupMode == _SetupMode.manual && !_scheduleExpanded) {
      if (_objective.text.trim().length < 3) {
        showToast(context, 'Add your main goal.');
        return;
      }
      setState(() => _scheduleExpanded = true);
      return;
    }
    if (_step == 2 && _setupMode == _SetupMode.manual && _days.isEmpty) {
      showToast(context, 'Choose at least one day that could work.');
      return;
    }
    if (_step == 2 && _setupMode == _SetupMode.aiVoice) {
      if (!_voiceComplete) {
        showToast(context, 'Answer the remaining voice questions first.');
        return;
      }
      setState(() => _step = 4);
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    final success = await context.appRead.finishOnboarding(
      name: _name.text,
      profileImageUrl: _profileImageUrl.text,
      objective: _objective.text,
      targetDate: _targetDate,
      avatarKey: _avatarKey,
      progressStyle: _progress,
      preferredDays: _days.toList(),
      preferredTime: _time,
      workingFrequency: switch (_frequency) {
        '2 times a week' => 2,
        '4 times a week' => 4,
        'Most days' => 7,
        _ => 3,
      },
      constraints: _constraints.text,
    );
    if (!success && mounted) {
      showToast(context, context.appRead.message ?? 'Please try again.');
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 2 && _setupMode == _SetupMode.manual && _scheduleExpanded) {
      setState(() => _scheduleExpanded = false);
      return;
    }
    if (_recording) unawaited(_cancelRecording());
    if (_step == 2 && _setupMode == _SetupMode.aiVoice) {
      unawaited(_voicePlayer.stop());
    }
    if (_step == 4 && _setupMode == _SetupMode.aiVoice) {
      setState(() => _step = 2);
      return;
    }
    setState(() => _step--);
  }

  void _selectSetup(_SetupMode mode) {
    setState(() {
      _setupMode = mode;
      _step = 2;
    });
    if (mode == _SetupMode.aiVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_voiceMessages.isEmpty) {
          unawaited(_startVoicePrompt());
        } else if (!_voiceComplete) {
          unawaited(_startListening());
        }
      });
    }
  }

  Future<void> _startVoicePrompt() async {
    if (_voiceBusy || !mounted) return;
    setState(() {
      _voiceBusy = true;
      _voiceError = null;
    });
    try {
      await _realtime.connect();
      final start = <String, dynamic>{
        'locale': WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag(),
      };
      if (_name.text.trim().isNotEmpty) start['name'] = _name.text.trim();
      _realtime.send('voice.start', start);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceError = error.message;
        });
      }
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString();
    final rawData = event['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    if (type == 'voice.status') {
      setState(() {
        _voiceBusy = true;
        _voiceError = null;
      });
      return;
    }
    if (type == 'voice.transcript') {
      final transcript = data['transcript']?.toString().trim() ?? '';
      if (transcript.isNotEmpty) {
        setState(() {
          _voiceMessages.add(_VoiceMessage(assistant: false, text: transcript));
        });
      }
      return;
    }
    if (type == 'voice.reply_text') {
      final answers = data['answers'];
      if (answers is Map) {
        _applyVoiceAnswers(Map<String, dynamic>.from(answers));
      }
      return;
    }
    if (type == 'voice.audio_start') {
      final reply = data['reply']?.toString().trim() ?? '';
      final answers = data['answers'];
      if (answers is Map) {
        _applyVoiceAnswers(Map<String, dynamic>.from(answers));
      }
      final complete = data['complete'] == true;
      final previousSource = _liveVoiceSource;
      final source = _LiveVoiceSource();
      _liveVoiceSource = source;
      unawaited(previousSource?.close());
      _prepareTypewriter(reply);
      setState(() {
        _voiceEnvelope = const [];
        _voiceDuration = Duration.zero;
        _voiceComplete = false;
        _voiceError = null;
      });
      unawaited(_playLiveVoice(source, finishAfterSpeech: complete));
      return;
    }
    if (type == 'voice.audio_chunk') {
      try {
        _liveVoiceSource?.add(_decodeVoiceAudio(data['audioBase64']));
      } on ApiException catch (error) {
        setState(() => _voiceError = error.message);
      }
      return;
    }
    if (type == 'voice.audio_end') {
      unawaited(_liveVoiceSource?.close());
      return;
    }
    if (type == 'voice.reply') {
      try {
        final reply = data['reply']?.toString().trim() ?? '';
        final audio = _decodeVoiceAudio(data['audioBase64']);
        final lipTrack = _wavLipTrack(audio);
        final answers = data['answers'];
        if (answers is Map) {
          _applyVoiceAnswers(Map<String, dynamic>.from(answers));
        }
        final complete = data['complete'] == true;
        _prepareTypewriter(reply);
        setState(() {
          _voiceEnvelope = lipTrack.envelope;
          _voiceDuration = lipTrack.duration;
          _voiceComplete = false;
          _voiceError = null;
        });
        unawaited(_playVoice(audio, finishAfterSpeech: complete));
      } on ApiException catch (error) {
        setState(() {
          _voiceBusy = false;
          _voiceError = error.message;
        });
      }
      return;
    }
    if (type == 'error' || type == 'transport.error') {
      setState(() {
        _voiceBusy = false;
        _voiceError =
            data['message']?.toString() ??
            'The live conversation was interrupted. Reconnecting…';
      });
    }
  }

  void _setAssistantMessage(String text) {
    setState(() {
      if (_voiceMessages.isNotEmpty && _voiceMessages.last.assistant) {
        _voiceMessages[_voiceMessages.length - 1] = _VoiceMessage(
          assistant: true,
          text: text,
        );
      } else {
        _voiceMessages.add(_VoiceMessage(assistant: true, text: text));
      }
    });
  }

  void _prepareTypewriter(String text) {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
    _voiceSpeechText = text;
    _voiceGlyphs = text.characters.toList(growable: false);
    _visibleVoiceGlyphs = 0;
    _typewriterStarted = false;
    _voiceProgress.value = 0;
  }

  void _startTypewriter() {
    if (_typewriterStarted || _voiceGlyphs.isEmpty || !mounted) return;
    _typewriterStarted = true;
    _revealNextVoiceGlyph();
    final measuredMs = _voiceDuration.inMilliseconds > 0
        ? _voiceDuration.inMilliseconds ~/ _voiceGlyphs.length
        : 72;
    final interval = Duration(milliseconds: measuredMs.clamp(42, 105));
    _typewriterTimer = Timer.periodic(interval, (_) {
      if (_voiceSpeaking) _revealNextVoiceGlyph();
    });
  }

  void _revealNextVoiceGlyph() {
    if (!mounted || _visibleVoiceGlyphs >= _voiceGlyphs.length) {
      _typewriterTimer?.cancel();
      _typewriterTimer = null;
      return;
    }
    _visibleVoiceGlyphs++;
    _setAssistantMessage(_voiceGlyphs.take(_visibleVoiceGlyphs).join());
    if (_voiceDuration == Duration.zero) {
      _voiceProgress.value = _visibleVoiceGlyphs / _voiceGlyphs.length;
    }
    if (_visibleVoiceGlyphs == _voiceGlyphs.length) {
      _typewriterTimer?.cancel();
      _typewriterTimer = null;
    }
  }

  void _completeTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
    if (!mounted || _voiceSpeechText.isEmpty) return;
    _visibleVoiceGlyphs = _voiceGlyphs.length;
    _setAssistantMessage(_voiceSpeechText);
    _voiceProgress.value = 1;
  }

  Future<void> _startListening() async {
    if (_step != 2 ||
        _setupMode != _SetupMode.aiVoice ||
        _voiceBusy ||
        _voiceSpeaking ||
        _recording ||
        _voiceComplete) {
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() {
          _voiceError =
              'Microphone access is needed for AI voice setup. You can also go back and choose manual setup.';
        });
      }
      return;
    }
    try {
      await _voicePlayer.stop();
      _recordingBytes = BytesBuilder(copy: false);
      _heardSpeech = false;
      _recordingStartedAt = DateTime.now();
      _lastSpeechAt = null;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _recordingSubscription = stream.listen(
        _onRecordingChunk,
        onError: (_) {
          if (mounted) {
            setState(() => _voiceError = 'Recording stopped unexpectedly.');
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _voiceError = null;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (
        timer,
      ) {
        if (!mounted || !_recording) return timer.cancel();
        final now = DateTime.now();
        final elapsed = now.difference(_recordingStartedAt!).inMilliseconds;
        final quietFor = _lastSpeechAt == null
            ? 0
            : now.difference(_lastSpeechAt!).inMilliseconds;
        if ((_heardSpeech && elapsed > 1400 && quietFor > 1250) ||
            elapsed >= 25000) {
          unawaited(_finishRecording());
        } else if (!_heardSpeech && elapsed >= 12000) {
          unawaited(_finishRecording());
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _voiceError = 'Could not start the microphone. Try again.',
        );
      }
    }
  }

  void _onRecordingChunk(Uint8List bytes) {
    _recordingBytes.add(bytes);
    if (bytes.length < 2) return;
    final samples = ByteData.sublistView(bytes);
    var sum = 0.0;
    var count = 0;
    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      final sample = samples.getInt16(offset, Endian.little) / 32768.0;
      sum += sample * sample;
      count++;
    }
    if (count > 0 && math.sqrt(sum / count) > .018) {
      _heardSpeech = true;
      _lastSpeechAt = DateTime.now();
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorder.cancel();
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _finishRecording() async {
    if (!_recording) return;
    setState(() {
      _recording = false;
      _voiceBusy = true;
      _voiceError = null;
    });
    _recordingTimer?.cancel();
    await _recorder.stop();
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    final pcm = _recordingBytes.takeBytes();
    if (!_heardSpeech || pcm.length < 3200) {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceError = 'I didn’t catch that. Tap to try again.';
        });
      }
      return;
    }
    try {
      await _realtime.connect();
      _realtime.send('voice.turn', {
        'audioBase64': base64Encode(_pcmAsWav(pcm)),
        'mimeType': 'audio/wav',
        'answers': _currentVoiceAnswers(),
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceError = error.message;
        });
      }
    }
  }

  Map<String, dynamic> _currentVoiceAnswers() {
    final answers = Map<String, dynamic>.from(_voiceAnswers);
    if (_name.text.trim().length >= 2) answers['name'] = _name.text.trim();
    return answers;
  }

  void _applyVoiceAnswers(Map<String, dynamic> answers) {
    _voiceAnswers
      ..clear()
      ..addAll(answers);
    final name = answers['name']?.toString().trim();
    if (name != null && name.isNotEmpty) _name.text = name;
    final objective = answers['objective']?.toString().trim();
    if (objective != null && objective.isNotEmpty) _objective.text = objective;
    final target = DateTime.tryParse(answers['targetDate']?.toString() ?? '');
    if (target != null) _targetDate = target;
    final days = answers['preferredDays'];
    if (days is List && days.isNotEmpty) {
      _days
        ..clear()
        ..addAll(days.map((day) => day.toString()));
    }
    final time = answers['preferredTime']?.toString();
    if (_timeOptions.contains(time)) _time = time!;
    final frequency = answers['workingFrequency'];
    if (frequency is num) {
      _frequency = switch (frequency.toInt()) {
        2 => '2 times a week',
        4 => '4 times a week',
        >= 5 => 'Most days',
        _ => '3 times a week',
      };
    }
    final progress = answers['progressStyle']?.toString();
    if (const ['Gentle', 'Balanced', 'Detailed'].contains(progress)) {
      _progress = progress!;
    }
    final constraints = answers['constraints']?.toString();
    if (constraints != null) _constraints.text = constraints;
  }

  Uint8List _decodeVoiceAudio(Object? value) {
    try {
      return base64Decode(value?.toString() ?? '');
    } catch (_) {
      throw const ApiException(
        'The assistant audio was incomplete. Try again.',
      );
    }
  }

  Future<void> _playVoice(
    Uint8List? audio, {
    bool finishAfterSpeech = false,
  }) async {
    if (audio == null || audio.isEmpty) {
      _completeTypewriter();
      await _finishVoicePlayback(finishAfterSpeech: finishAfterSpeech);
      return;
    }
    try {
      await _voicePlayer.stop();
      _voiceProgress.value = 0;
      await _voicePlayer.setAudioSource(_MemoryVoiceSource(audio, 'audio/wav'));
      await _playUntilStopped().timeout(
        Duration(
          milliseconds: math.max(5000, _voiceDuration.inMilliseconds + 5000),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _voiceError = finishAfterSpeech
              ? 'Audio could not play, but your plan is ready to review.'
              : 'Audio could not play, so I’m listening for your answer now.',
        );
      }
    }
    _completeTypewriter();
    await _finishVoicePlayback(finishAfterSpeech: finishAfterSpeech);
  }

  Future<void> _playLiveVoice(
    _LiveVoiceSource source, {
    required bool finishAfterSpeech,
  }) async {
    try {
      await _voicePlayer.stop();
      _voiceProgress.value = 0;
      await _voicePlayer.setAudioSource(source);
      final timeoutMs = math.max(20000, _voiceGlyphs.length * 120 + 10000);
      await _playUntilStopped(
        streamEnded: source.ended,
      ).timeout(Duration(milliseconds: timeoutMs));
    } catch (_) {
      if (mounted) {
        setState(
          () => _voiceError = finishAfterSpeech
              ? 'Audio could not play, but your plan is ready to review.'
              : 'Audio could not play, so I’m listening for your answer now.',
        );
      }
    } finally {
      await source.close();
      if (identical(_liveVoiceSource, source)) _liveVoiceSource = null;
    }
    _completeTypewriter();
    await _finishVoicePlayback(finishAfterSpeech: finishAfterSpeech);
  }

  Future<void> _playUntilStopped({Future<void>? streamEnded}) {
    var started = false;
    final stopped = _voicePlayer.playerStateStream
        .firstWhere((state) {
          if (state.playing) started = true;
          return started &&
              (!state.playing ||
                  state.processingState == ProcessingState.completed);
        })
        .then((_) {});
    return Future.any([
      _voicePlayer.play(),
      stopped,
      if (streamEnded != null) _finishWhenStreamDrains(streamEnded),
    ]);
  }

  Future<void> _finishWhenStreamDrains(Future<void> streamEnded) async {
    await streamEnded;
    var lastPosition = _voicePlayer.position;
    var stableChecks = 0;
    while (stableChecks < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final position = _voicePlayer.position;
      if (position > lastPosition + const Duration(milliseconds: 20)) {
        stableChecks = 0;
      } else {
        stableChecks++;
      }
      lastPosition = position;
    }
  }

  Future<void> _finishVoicePlayback({required bool finishAfterSpeech}) async {
    if (!mounted) return;
    setState(() {
      _voiceSpeaking = false;
      _voiceBusy = false;
      if (finishAfterSpeech) _voiceComplete = true;
    });
    if (finishAfterSpeech) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted &&
          _voiceComplete &&
          _step == 2 &&
          _setupMode == _SetupMode.aiVoice) {
        await _next();
      }
      return;
    }
  }

  Uint8List _pcmAsWav(Uint8List pcm) {
    const sampleRate = 16000;
    final header = ByteData(44);
    void ascii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        header.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.app;
    return Theme(
      data: onwardTheme(dark: false),
      child: Builder(
        builder: (lightContext) => Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          backgroundColor: const Color(0xFFFFF7D5),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: OnwardColors.ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: onwardSystemUiOverlayStyle(dark: false)
                .copyWith(
                  systemNavigationBarColor: const Color(0xFFFFF7D5),
                  systemNavigationBarDividerColor: const Color(0xFFFFF7D5),
                ),
            leading: _step == 0
                ? null
                : IconButton(
                    onPressed: _back,
                    tooltip: 'Previous step',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
            title: const OnwardWordmark(compact: true),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$_visibleStep of $_visibleStepCount',
                          style: Theme.of(lightContext).textTheme.labelMedium
                              ?.copyWith(
                                color: OnwardColors.ink.withValues(alpha: .68),
                                fontSize: 12,
                                letterSpacing: .1,
                              ),
                        ),
                        const SizedBox(height: 4),
                        ProgressLine(
                          value: _visibleStep / _visibleStepCount,
                          height: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/avatars/character-garden-background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'Whimsical garden background',
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: kToolbarHeight),
                  child: ContentWidth(
                    maxWidth: 600,
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                ),
                            child: _step == 0
                                ? Padding(
                                    key: const ValueKey('character-step'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: _stepContent(lightContext),
                                  )
                                : SingleChildScrollView(
                                    key: ValueKey(_step),
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      24,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child:
                                          _step == 1 ||
                                              (_step == 2 &&
                                                  _setupMode ==
                                                      _SetupMode.aiVoice)
                                          ? _stepContent(lightContext)
                                          : _OnboardingSurface(
                                              child: _stepContent(lightContext),
                                            ),
                                    ),
                                  ),
                          ),
                        ),
                        if (_step != 1 &&
                            !(_step == 2 && _setupMode == _SetupMode.aiVoice))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: _PressableNeumorphic(
                                enabled:
                                    !state.busy &&
                                    !_voiceBusy &&
                                    !(_step == 2 &&
                                        _setupMode == _SetupMode.aiVoice &&
                                        !_voiceComplete),
                                color: Theme.of(
                                  lightContext,
                                ).colorScheme.primary,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                  ),
                                  onPressed:
                                      state.busy ||
                                          _voiceBusy ||
                                          (_step == 2 &&
                                              _setupMode ==
                                                  _SetupMode.aiVoice &&
                                              !_voiceComplete)
                                      ? null
                                      : _next,
                                  child: state.busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _step == 4
                                              ? 'Finish setup'
                                              : _step == 2 &&
                                                    _setupMode ==
                                                        _SetupMode.aiVoice
                                              ? 'Review my answers'
                                              : 'Next',
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context) => switch (_step) {
    0 => _CharacterStep(
      avatarKey: _avatarKey,
      section: _avatarSection,
      onSectionChanged: (value) => setState(() => _avatarSection = value),
      onAvatarChanged: (value) => setState(() => _avatarKey = value),
    ),
    1 => _SetupModeStep(
      onManual: () => _selectSetup(_SetupMode.manual),
      onAiVoice: () => _selectSetup(_SetupMode.aiVoice),
    ),
    2 =>
      _setupMode == _SetupMode.aiVoice
          ? _VoiceOnboardingStep(
              messages: _voiceMessages,
              busy: _voiceBusy,
              recording: _recording,
              speaking: _voiceSpeaking,
              complete: _voiceComplete,
              lipSyncProgress: _voiceProgress,
              speechText: _voiceSpeechText,
              speechEnvelope: _voiceEnvelope,
              error: _voiceError,
              onSpeak: () => unawaited(_startListening()),
            )
          : _GoalSetupStep(
              objective: _objective,
              scheduleExpanded: _scheduleExpanded,
              days: _days,
              dayOptions: _dayOptions,
              frequency: _frequency,
              targetDate: _targetDate,
              onDay: (day) => setState(
                () => _days.contains(day) ? _days.remove(day) : _days.add(day),
              ),
              onFrequency: (value) => setState(() => _frequency = value),
              onTargetDate: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (selected != null && mounted) {
                  setState(() => _targetDate = selected);
                }
              },
            ),
    3 => _PreferencesStep(
      time: _time,
      timeOptions: _timeOptions,
      progress: _progress,
      constraints: _constraints,
      onTime: (value) => setState(() => _time = value),
      onProgress: (value) => setState(() => _progress = value),
    ),
    _ => _OnboardingReview(
      name: _name.text,
      profileImageUrl: _profileImageUrl.text,
      avatarKey: _avatarKey,
      objective: _objective.text,
      days: _days.toList(),
      time: _time,
      frequency: _frequency,
      progress: _progress,
      targetDate: _targetDate,
    ),
  };
}

class _SetupModeStep extends StatelessWidget {
  const _SetupModeStep({required this.onManual, required this.onAiVoice});

  final VoidCallback onManual;
  final VoidCallback onAiVoice;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SetupOption(
        icon: Icons.graphic_eq_rounded,
        title: 'Talk it out.\nWe\'ll build the plan.',
        description:
            'Answer a few short questions in the language you naturally speak.',
        color: OnwardColors.pink,
        action: 'Start with voice',
        filled: true,
        onTap: onAiVoice,
      ),
      const SizedBox(height: 14),
      _SetupOption(
        icon: Icons.edit_note_rounded,
        title: 'Prefer to type?',
        description: 'Build your goal manually',
        color: OnwardColors.cream,
        action: 'Set up manually',
        onTap: onManual,
      ),
    ],
  );
}

class _SetupOption extends StatelessWidget {
  const _SetupOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.action,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String action;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return Semantics(
        button: true,
        label: action,
        child: Material(
          color: Colors.white.withValues(alpha: .88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: OnwardColors.ink.withValues(alpha: .1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: OnwardColors.ink, size: 23),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: OnwardColors.ink.withValues(alpha: .62),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DD).withValues(alpha: .86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .8)),
        boxShadow: [
          BoxShadow(
            color: OnwardColors.ink.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 210,
              height: 164,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/illustrations/onward-human-guide.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.high,
                  ),
                  CustomPaint(
                    painter: const _GuideFacePainter(
                      blink: 0,
                      mouthOpen: 0,
                      mouthShape: _MouthShape.closed,
                      listening: false,
                      thinking: false,
                      speaking: false,
                      complete: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: OnwardColors.ink,
              fontSize: 25,
              height: 1.08,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF541CC7),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceOnboardingStep extends StatelessWidget {
  const _VoiceOnboardingStep({
    required this.messages,
    required this.busy,
    required this.recording,
    required this.speaking,
    required this.complete,
    required this.lipSyncProgress,
    required this.speechText,
    required this.speechEnvelope,
    required this.error,
    required this.onSpeak,
  });

  final List<_VoiceMessage> messages;
  final bool busy;
  final bool recording;
  final bool speaking;
  final bool complete;
  final ValueNotifier<double> lipSyncProgress;
  final String speechText;
  final List<double> speechEnvelope;
  final String? error;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    String? assistantText;
    String? userText;
    for (final message in messages) {
      if (message.assistant) {
        assistantText = message.text;
      } else {
        userText = message.text;
      }
    }
    final status = recording
        ? 'Listening — speak naturally'
        : busy
        ? messages.isEmpty
              ? 'Getting ready…'
              : 'Thinking…'
        : speaking
        ? 'Speaking'
        : complete
        ? 'Plan ready'
        : 'Ready';
    final accent = recording
        ? const Color(0xFF6D4BD1)
        : busy
        ? const Color(0xFFE6A72D)
        : complete
        ? const Color(0xFF4E9B6D)
        : Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Let’s shape your goal',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: OnwardColors.ink,
            fontSize: 27,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedContainer(
          key: const ValueKey('voice-mascot-stage'),
          duration: const Duration(milliseconds: 280),
          height: 278,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: .7)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 16,
                left: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    status,
                    key: ValueKey(status),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: accent.withValues(alpha: .92),
                      fontWeight: FontWeight.w700,
                      letterSpacing: .15,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _VoiceMascot(
                  listening: recording,
                  thinking: busy,
                  speaking: speaking,
                  complete: complete,
                  lipSyncProgress: lipSyncProgress,
                  speechText: speechText,
                  speechEnvelope: speechEnvelope,
                ),
              ),
              if (complete)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4E9B6D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .78)),
          ),
          child: Text(
            assistantText ??
                (busy
                    ? 'One moment—I’m getting our conversation ready.'
                    : 'Tap to speak when you’re ready. I’ll wait for you.'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OnwardColors.ink,
              height: 1.4,
            ),
          ),
        ),
        if (userText != null) ...[
          const SizedBox(height: 10),
          Semantics(
            label: 'You said: $userText',
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 430),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'You said: $userText',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OnwardColors.ink.withValues(alpha: .72),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9E5).withValues(alpha: .94),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFFE85C67).withValues(alpha: .18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: Color(0xFFAD3E47),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(error!)),
              ],
            ),
          ),
        ],
        if (!busy && !speaking && !complete) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                key: const ValueKey('voice-onboarding-mic'),
                onPressed: recording ? null : onSpeak,
                tooltip: recording ? 'Listening' : 'Tap to speak',
                icon: Icon(
                  recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Text(recording ? 'Listening…' : 'Tap to speak'),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: onwardMuted(context),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                complete
                    ? 'Your answers are ready to review.'
                    : recording
                    ? 'Stops automatically when you pause.'
                    : 'Tap the mic when you are ready · audio isn’t stored.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onwardMuted(context),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VoiceMascot extends StatefulWidget {
  const _VoiceMascot({
    required this.listening,
    required this.thinking,
    required this.speaking,
    required this.complete,
    required this.lipSyncProgress,
    required this.speechText,
    required this.speechEnvelope,
  });

  final bool listening;
  final bool thinking;
  final bool speaking;
  final bool complete;
  final ValueNotifier<double> lipSyncProgress;
  final String speechText;
  final List<double> speechEnvelope;

  @override
  State<_VoiceMascot> createState() => _VoiceMascotState();
}

class _VoiceMascotState extends State<_VoiceMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();
  double _smoothedMouthOpen = 0;
  double _lastSpeechProgress = 0;
  String _lastSpeechText = '';
  _MouthShape _displayedMouthShape = _MouthShape.closed;
  _MouthShape _candidateMouthShape = _MouthShape.closed;
  int _candidateFrames = 0;

  double _blinkAt(double t, double center) {
    final distance = (t - center).abs();
    if (distance >= .025) return 0;
    return 1 - (distance / .025);
  }

  @override
  void initState() {
    super.initState();
    assert(_mouthShapeFor('m', 0) == _MouthShape.closed);
    assert(_mouthShapeFor('o', 0) == _MouthShape.round);
    assert(_mouthShapeFor('e', 0) == _MouthShape.wide);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.listening
        ? 'Tara is listening'
        : widget.thinking
        ? 'Tara is thinking'
        : widget.speaking
        ? 'Tara is speaking'
        : widget.complete
        ? 'Tara completed your plan'
        : 'Tara is ready',
    child: SizedBox(
      key: const ValueKey('voice-onboarding-mascot'),
      width: 260,
      height: 228,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final t = _motion.value;
            final breath = math.sin(t * math.pi * 2);
            final blink = math.max(_blinkAt(t, .22), _blinkAt(t, .76));
            final speechProgress = widget.lipSyncProgress.value;
            if (_lastSpeechText != widget.speechText ||
                speechProgress + .03 < _lastSpeechProgress) {
              _lastSpeechText = widget.speechText;
              _displayedMouthShape = _MouthShape.closed;
              _candidateMouthShape = _MouthShape.closed;
              _candidateFrames = 0;
              _smoothedMouthOpen = 0;
            }
            _lastSpeechProgress = speechProgress;
            final energy = widget.speaking
                ? _speechEnergy(widget.speechEnvelope, speechProgress)
                : 0.0;
            final targetOpen = energy < .14
                ? 0.0
                : Curves.easeInOut.transform(
                    (.08 + energy * .70).clamp(0.0, .78),
                  );
            _smoothedMouthOpen +=
                (targetOpen - _smoothedMouthOpen) *
                (targetOpen > _smoothedMouthOpen ? .16 : .24);
            if (_smoothedMouthOpen < .025) _smoothedMouthOpen = 0;

            final cueCount = widget.speechEnvelope.isEmpty
                ? math.max(1, widget.speechText.runes.length ~/ 4)
                : math.max(1, widget.speechEnvelope.length ~/ 7);
            final requestedShape = _smoothedMouthOpen < .07
                ? _MouthShape.closed
                : _mouthShapeFor(
                    widget.speechText,
                    speechProgress,
                    cueCount: cueCount,
                  );
            if (requestedShape == _displayedMouthShape) {
              _candidateFrames = 0;
            } else if (requestedShape != _candidateMouthShape) {
              _candidateMouthShape = requestedShape;
              _candidateFrames = 1;
            } else {
              _candidateFrames++;
              if (_candidateFrames >= 5 ||
                  requestedShape == _MouthShape.closed) {
                _displayedMouthShape = requestedShape;
                _candidateFrames = 0;
              }
            }
            final mouthOpen = _smoothedMouthOpen.clamp(0.0, .78);
            final mouthShape = mouthOpen < .05
                ? _MouthShape.closed
                : _displayedMouthShape;
            final nodPhase = ((t - .42) / .20).clamp(0.0, 1.0);
            final nod = t >= .42 && t <= .62
                ? math.sin(nodPhase * math.pi)
                : 0.0;
            final turn = math.sin(t * math.pi * 2);
            final scale = 1 + breath * (widget.listening ? .007 : .0035);
            final headX = widget.thinking
                ? -1.2
                : widget.listening
                ? .7
                : widget.speaking
                ? turn * .75
                : turn * .35;
            final headY = widget.complete
                ? -.8
                : widget.speaking
                ? nod * .75
                : widget.listening
                ? -.35
                : 0.0;
            final angle = widget.thinking
                ? -.014
                : widget.listening
                ? .009
                : widget.speaking
                ? turn * .006
                : turn * .0025;
            return Transform.translate(
              offset: Offset(headX, breath * -1.05 + headY),
              child: Transform.rotate(
                angle: angle,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/illustrations/onward-human-guide.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.high,
                      ),
                      CustomPaint(
                        painter: _GuideFacePainter(
                          blink: blink,
                          mouthOpen: mouthOpen,
                          mouthShape: mouthShape,
                          listening: widget.listening,
                          thinking: widget.thinking,
                          speaking: widget.speaking,
                          complete: widget.complete,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _GuideFacePainter extends CustomPainter {
  const _GuideFacePainter({
    required this.blink,
    required this.mouthOpen,
    required this.mouthShape,
    required this.listening,
    required this.thinking,
    required this.speaking,
    required this.complete,
  });

  final double blink;
  final double mouthOpen;
  final _MouthShape mouthShape;
  final bool listening;
  final bool thinking;
  final bool speaking;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final square = size.height;
    final dx = (size.width - square) / 2;
    Offset point(double x, double y) => Offset(dx + square * x, square * y);
    const ink = Color(0xFF332330);
    const eyeWhite = Color(0xFFFFFCF5);
    const iris = Color(0xFF4A2D25);
    const skinLine = Color(0xFFA75A42);
    const lip = Color(0xFFA84F62);
    const lipDark = Color(0xFF6C3043);
    const mouthInterior = Color(0xFF562B38);
    final pupilShift = thinking
        ? const Offset(1.7, -1.2)
        : listening
        ? const Offset(0, .45)
        : Offset.zero;

    for (final x in const [.444, .556]) {
      final center = point(x, .271);
      final halfWidth = 7.2;
      final open = math.max(.35, 3.7 * (1 - blink));
      final eye = Path()
        ..moveTo(center.dx - halfWidth, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy - open,
          center.dx + halfWidth,
          center.dy,
        )
        ..quadraticBezierTo(
          center.dx,
          center.dy + open * .78,
          center.dx - halfWidth,
          center.dy,
        )
        ..close();
      canvas.drawPath(eye, Paint()..color = eyeWhite);
      if (blink < .82) {
        final pupil = center + pupilShift;
        canvas.save();
        canvas.clipPath(eye);
        canvas.drawCircle(pupil, 3.5, Paint()..color = iris);
        canvas.drawCircle(pupil, 1.9, Paint()..color = ink);
        canvas.drawCircle(
          pupil + const Offset(-1.2, -1.25),
          .75,
          Paint()..color = Colors.white,
        );
        canvas.restore();
      }
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - halfWidth, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy - open,
            center.dx + halfWidth,
            center.dy,
          ),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.65,
      );
    }

    final browPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.15;
    final browLift = listening ? -2.2 : 0.0;
    final leftBrow = Path()
      ..moveTo(point(.405, .229).dx, point(.405, .229).dy + browLift)
      ..quadraticBezierTo(
        point(.44, .213).dx,
        point(.44, .213).dy + browLift,
        point(.474, .229).dx,
        point(.474, .229).dy + (thinking ? 2 : browLift),
      );
    final rightBrow = Path()
      ..moveTo(
        point(.526, .229).dx,
        point(.526, .229).dy + (thinking ? 2 : browLift),
      )
      ..quadraticBezierTo(
        point(.56, .213).dx,
        point(.56, .213).dy + browLift,
        point(.595, .229).dx,
        point(.595, .229).dy + browLift,
      );
    canvas.drawPath(leftBrow, browPaint);
    canvas.drawPath(rightBrow, browPaint);

    final nose = Path()
      ..moveTo(point(.499, .286).dx, point(.499, .286).dy)
      ..quadraticBezierTo(
        point(.489, .312).dx,
        point(.489, .312).dy,
        point(.505, .317).dx,
        point(.505, .317).dy,
      );
    canvas.drawPath(
      nose,
      Paint()
        ..color = skinLine.withValues(alpha: .46)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.45,
    );

    if (complete || listening) {
      final blushPaint = Paint()
        ..color = const Color(0xFFE98778).withValues(alpha: .13);
      canvas.drawOval(
        Rect.fromCenter(center: point(.42, .326), width: 12, height: 5),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: point(.58, .326), width: 12, height: 5),
        blushPaint,
      );
    }

    final mouthCenter = point(.5, .35);
    if (speaking && mouthShape == _MouthShape.closed) {
      final closedLip = Path()
        ..moveTo(mouthCenter.dx - 7, mouthCenter.dy)
        ..quadraticBezierTo(
          mouthCenter.dx - 2,
          mouthCenter.dy - 2.1,
          mouthCenter.dx,
          mouthCenter.dy - .55,
        )
        ..quadraticBezierTo(
          mouthCenter.dx + 2,
          mouthCenter.dy - 2.1,
          mouthCenter.dx + 7,
          mouthCenter.dy,
        )
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + 3.2,
          mouthCenter.dx - 7,
          mouthCenter.dy,
        )
        ..close();
      canvas.drawPath(closedLip, Paint()..color = lip);
      canvas.drawLine(
        mouthCenter - const Offset(5.4, 0),
        mouthCenter + const Offset(5.4, 0),
        Paint()
          ..color = lipDark
          ..strokeWidth = 1.05
          ..strokeCap = StrokeCap.round,
      );
    } else if (speaking) {
      final dimensions = switch (mouthShape) {
        _MouthShape.open => (15.5, 3.3 + mouthOpen * 8.5),
        _MouthShape.wide => (18.5, 3.0 + mouthOpen * 5.3),
        _MouthShape.round => (9.0 + mouthOpen * 2.5, 4.5 + mouthOpen * 7),
        _MouthShape.teeth => (17.5, 3.0 + mouthOpen * 5.2),
        _ => (13.5, 2.2 + mouthOpen * 6.5),
      };
      final halfWidth = dimensions.$1 / 2;
      final halfHeight = dimensions.$2 / 2;
      final mouth = Path()
        ..moveTo(mouthCenter.dx - halfWidth, mouthCenter.dy)
        ..cubicTo(
          mouthCenter.dx - halfWidth * .48,
          mouthCenter.dy - halfHeight * .92,
          mouthCenter.dx - halfWidth * .2,
          mouthCenter.dy - halfHeight,
          mouthCenter.dx,
          mouthCenter.dy - halfHeight * .72,
        )
        ..cubicTo(
          mouthCenter.dx + halfWidth * .2,
          mouthCenter.dy - halfHeight,
          mouthCenter.dx + halfWidth * .48,
          mouthCenter.dy - halfHeight * .92,
          mouthCenter.dx + halfWidth,
          mouthCenter.dy,
        )
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + halfHeight,
          mouthCenter.dx - halfWidth,
          mouthCenter.dy,
        )
        ..close();
      canvas.drawPath(
        mouth,
        Paint()
          ..color = mouthInterior
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        mouth,
        Paint()
          ..color = lip
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.8,
      );
      canvas.save();
      canvas.clipPath(mouth);
      final showTeeth =
          mouthShape == _MouthShape.teeth ||
          (mouthShape == _MouthShape.wide && mouthOpen > .34);
      if (showTeeth) {
        final teethHeight = math.min(3.8, dimensions.$2 * .38);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              mouthCenter.dx - halfWidth + 1.1,
              mouthCenter.dy - halfHeight * .72,
              dimensions.$1 - 2.2,
              teethHeight,
            ),
            const Radius.circular(1.5),
          ),
          Paint()..color = const Color(0xFFFFF8E8),
        );
      }
      if (!showTeeth && mouthOpen > .4 && mouthShape != _MouthShape.round) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(mouthCenter.dx, mouthCenter.dy + halfHeight * .78),
            width: dimensions.$1 * .58,
            height: 5.5,
          ),
          Paint()..color = const Color(0xFFE98478),
        );
      }
      canvas.restore();
      canvas.drawPath(
        Path()
          ..moveTo(mouthCenter.dx - halfWidth * .82, mouthCenter.dy - .2)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy - halfHeight * 1.03,
            mouthCenter.dx + halfWidth * .82,
            mouthCenter.dy - .2,
          ),
        Paint()
          ..color = lipDark.withValues(alpha: .72)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .8,
      );
    } else {
      final width = complete ? 9.5 : 7.8;
      final smile = complete
          ? 3.8
          : thinking
          ? 1.2
          : listening
          ? 2.0
          : 2.5;
      final restingLips = Path()
        ..moveTo(mouthCenter.dx - width, mouthCenter.dy)
        ..quadraticBezierTo(
          mouthCenter.dx - 2.4,
          mouthCenter.dy - 2.2,
          mouthCenter.dx,
          mouthCenter.dy - .55,
        )
        ..quadraticBezierTo(
          mouthCenter.dx + 2.4,
          mouthCenter.dy - 2.2,
          mouthCenter.dx + width,
          mouthCenter.dy,
        )
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + smile,
          mouthCenter.dx - width,
          mouthCenter.dy,
        )
        ..close();
      canvas.drawPath(
        restingLips,
        Paint()..color = complete ? lip : lip.withValues(alpha: .9),
      );
      canvas.drawPath(
        Path()
          ..moveTo(mouthCenter.dx - width * .78, mouthCenter.dy)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy + smile * .45,
            mouthCenter.dx + width * .78,
            mouthCenter.dy,
          ),
        Paint()
          ..color = lipDark
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .85,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GuideFacePainter oldDelegate) =>
      oldDelegate.blink != blink ||
      oldDelegate.mouthOpen != mouthOpen ||
      oldDelegate.mouthShape != mouthShape ||
      oldDelegate.listening != listening ||
      oldDelegate.thinking != thinking ||
      oldDelegate.speaking != speaking ||
      oldDelegate.complete != complete;
}

class _OnboardingGlassSurface extends StatelessWidget {
  const _OnboardingGlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.tint = Colors.white,
    this.tintOpacity = .26,
    this.borderOpacity = .76,
    this.solid = false,
    this.showShadow = false,
    this.constraints,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;
  final double tintOpacity;
  final double borderOpacity;
  final bool solid;
  final bool showShadow;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final glass = Container(
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: solid ? tint : null,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: (tintOpacity + .08).clamp(0, 1)),
                  tint.withValues(alpha: tintOpacity),
                  Colors.white.withValues(alpha: tintOpacity * .6),
                ],
                stops: const [0, .48, 1],
              ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
          width: 1.1,
        ),
      ),
      child: child,
    );
    return Container(
      constraints: constraints,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF5B4A26).withValues(alpha: .16),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: glass,
      ),
    );
  }
}

class _OnboardingSurface extends StatelessWidget {
  const _OnboardingSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _OnboardingGlassSurface(
    constraints: const BoxConstraints(minWidth: double.infinity),
    padding: const EdgeInsets.all(20),
    radius: 26,
    tintOpacity: .34,
    borderOpacity: .9,
    showShadow: true,
    child: child,
  );
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: OnwardColors.ink,
                fontSize: 21,
                height: 1.14,
                fontWeight: FontWeight.w600,
                letterSpacing: -.45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OnwardColors.ink.withValues(alpha: .68),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _OnboardingGlassSurface(
    padding: const EdgeInsets.all(14),
    radius: 18,
    tintOpacity: .26,
    borderOpacity: .78,
    showShadow: false,
    constraints: const BoxConstraints(minWidth: double.infinity),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: OnwardColors.ink.withValues(alpha: .88),
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    ),
  );
}

class _PastelChoice extends StatelessWidget {
  const _PastelChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: _OnboardingGlassSurface(
      padding: EdgeInsets.zero,
      tint: selected ? Theme.of(context).colorScheme.primary : Colors.white,
      tintOpacity: selected ? .88 : .65,
      borderOpacity: selected ? .76 : .88,
      solid: selected,
      showShadow: false,
      radius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CharacterStep extends StatelessWidget {
  const _CharacterStep({
    required this.avatarKey,
    required this.section,
    required this.onSectionChanged,
    required this.onAvatarChanged,
  });

  final String avatarKey;
  final String section;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<String> onAvatarChanged;

  void _cycle(int direction) {
    final options = switch (section) {
      'Top' => onwardAvatarTops,
      'Bottom' => onwardAvatarBottoms,
      _ => onwardAvatarHeads,
    };
    final current = switch (section) {
      'Top' => onwardAvatarTop(avatarKey),
      'Bottom' => onwardAvatarBottom(avatarKey),
      _ => onwardAvatarHead(avatarKey),
    };
    final next =
        options[(options.indexOf(current) + direction) % options.length];
    onAvatarChanged(
      onwardAvatarKey(
        head: section == 'Head' ? next : onwardAvatarHead(avatarKey),
        top: section == 'Top' ? next : onwardAvatarTop(avatarKey),
        bottom: section == 'Bottom' ? next : onwardAvatarBottom(avatarKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final previewHeight = constraints.maxHeight;
      return SizedBox(
        key: const ValueKey('character-garden-stage'),
        width: double.infinity,
        height: previewHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Text(
                'Choose your character',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF20212A),
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.35,
                ),
              ),
            ),
            Positioned(
              top: previewHeight * .16,
              bottom: previewHeight * .25,
              left: 44,
              right: 44,
              child: OnwardCharacter(avatarKey: avatarKey),
            ),
            Positioned(
              left: 12,
              top: previewHeight * .43,
              child: _CharacterArrow(
                icon: Icons.chevron_left_rounded,
                label: 'Previous $section option',
                onPressed: () => _cycle(-1),
              ),
            ),
            Positioned(
              right: 12,
              top: previewHeight * .43,
              child: _CharacterArrow(
                icon: Icons.chevron_right_rounded,
                label: 'Next $section option',
                onPressed: () => _cycle(1),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final value in const ['Head', 'Top', 'Bottom']) ...[
                    if (value != 'Head') const SizedBox(width: 12),
                    _CharacterPartButton(
                      label: value,
                      selected: section == value,
                      onPressed: () => onSectionChanged(value),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CharacterArrow extends StatelessWidget {
  const _CharacterArrow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 38,
    height: 38,
    child: IconButton.filledTonal(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      tooltip: label,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE9EEF2).withValues(alpha: .94),
        foregroundColor: const Color(0xFF23273A),
      ),
      icon: Icon(icon, size: 24),
    ),
  );
}

class _CharacterPartButton extends StatelessWidget {
  const _CharacterPartButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: .94),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : const Color(0xFF30304B),
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    ),
  );
}

class _GoalSetupStep extends StatelessWidget {
  const _GoalSetupStep({
    required this.objective,
    required this.scheduleExpanded,
    required this.days,
    required this.dayOptions,
    required this.frequency,
    required this.targetDate,
    required this.onDay,
    required this.onFrequency,
    required this.onTargetDate,
  });

  final TextEditingController objective;
  final bool scheduleExpanded;
  final Set<String> days;
  final List<String> dayOptions;
  final String frequency;
  final DateTime targetDate;
  final ValueChanged<String> onDay;
  final ValueChanged<String> onFrequency;
  final VoidCallback onTargetDate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StepHeading(
        icon: Icons.track_changes_rounded,
        title: 'Set your first goal',
        subtitle:
            'Tell us what you want to achieve. You can edit these settings later.',
        color: OnwardColors.cream,
      ),
      const SizedBox(height: 24),
      _NeumorphicField(
        glass: true,
        child: TextField(
          controller: objective,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What goal do you want to achieve?',
            hintText: 'Run 5 km, learn Spanish, save for a deposit…',
            alignLabelWithHint: true,
          ),
        ),
      ),
      AnimatedSize(
        key: const ValueKey('schedule-expansion'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: scheduleExpanded
            ? Column(
                key: const ValueKey('expanded-schedule'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const _StepHeading(
                    icon: Icons.calendar_month_rounded,
                    title: 'Set your schedule',
                    subtitle: 'Choose the days and frequency you can maintain.',
                    color: OnwardColors.mint,
                  ),
                  const SizedBox(height: 18),
                  _ChoicePanel(
                    title: 'Preferred days',
                    children: [
                      for (final day in dayOptions)
                        _PastelChoice(
                          label: day,
                          selected: days.contains(day),
                          onSelected: () => onDay(day),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _OnboardingGlassSurface(
                    padding: EdgeInsets.zero,
                    radius: 18,
                    tintOpacity: .26,
                    borderOpacity: .78,
                    child: ListTile(
                      leading: const Icon(Icons.event_available_rounded),
                      title: const Text('Goal timeframe'),
                      subtitle: Text(
                        'Target ${targetDate.day}/${targetDate.month}/${targetDate.year}',
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: onTargetDate,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChoicePanel(
                    title: 'Weekly frequency',
                    children: [
                      for (final value in const [
                        '2 times a week',
                        '3 times a week',
                        '4 times a week',
                        'Most days',
                      ])
                        _PastelChoice(
                          label: value,
                          selected: frequency == value,
                          onSelected: () => onFrequency(value),
                        ),
                    ],
                  ),
                ],
              )
            : const SizedBox.shrink(key: ValueKey('collapsed-schedule')),
      ),
    ],
  );
}

class _PreferencesStep extends StatelessWidget {
  const _PreferencesStep({
    required this.time,
    required this.timeOptions,
    required this.progress,
    required this.constraints,
    required this.onTime,
    required this.onProgress,
  });

  final String time;
  final List<String> timeOptions;
  final String progress;
  final TextEditingController constraints;
  final ValueChanged<String> onTime;
  final ValueChanged<String> onProgress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _StepHeading(
        icon: Icons.tune_rounded,
        title: 'Fine-tune your plan',
        subtitle: 'Choose when to work and how much progress detail you want.',
        color: OnwardColors.pink,
      ),
      const SizedBox(height: 24),
      _ChoicePanel(
        title: 'Best time',
        children: [
          for (final value in timeOptions)
            _PastelChoice(
              label: value,
              selected: time == value,
              onSelected: () => onTime(value),
            ),
        ],
      ),
      const SizedBox(height: 14),
      _ChoicePanel(
        title: 'Progress view',
        children: [
          for (final value in const ['Gentle', 'Balanced', 'Detailed'])
            _PastelChoice(
              label: value,
              selected: progress == value,
              onSelected: () => onProgress(value),
            ),
        ],
      ),
      const SizedBox(height: 14),
      _NeumorphicField(
        glass: true,
        child: TextField(
          controller: constraints,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Scheduling constraints (optional)',
            hintText: 'Shift work, unavailable days, fixed commitments…',
            alignLabelWithHint: true,
          ),
        ),
      ),
    ],
  );
}

class _OnboardingReview extends StatelessWidget {
  const _OnboardingReview({
    required this.name,
    required this.profileImageUrl,
    required this.avatarKey,
    required this.objective,
    required this.days,
    required this.time,
    required this.frequency,
    required this.progress,
    required this.targetDate,
  });

  final String name;
  final String profileImageUrl;
  final String avatarKey;
  final String objective;
  final List<String> days;
  final String time;
  final String frequency;
  final String progress;
  final DateTime targetDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          icon: Icons.celebration_rounded,
          title: 'Review your setup',
          subtitle:
              'Confirm these defaults before creating your first detailed goal.',
          color: OnwardColors.cream,
        ),
        const SizedBox(height: 24),
        _OnboardingGlassSurface(
          padding: const EdgeInsets.all(16),
          radius: 18,
          tintOpacity: .26,
          borderOpacity: .78,
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OnwardAvatar(
                    name: name,
                    avatarKey: avatarKey,
                    profileImageUrl: profileImageUrl,
                    radius: 25,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(objective, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              _ReviewLine(
                icon: Icons.calendar_today_outlined,
                label: days.join(', '),
              ),
              const SizedBox(height: 14),
              _ReviewLine(
                icon: Icons.schedule_rounded,
                label: '$time · $frequency',
              ),
              const SizedBox(height: 14),
              _ReviewLine(icon: Icons.insights_outlined, label: progress),
              const SizedBox(height: 14),
              _ReviewLine(
                icon: Icons.flag_outlined,
                label:
                    'Target ${targetDate.day}/${targetDate.month}/${targetDate.year}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'You can change any of this later in Your preferences.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: onwardMuted(context)),
        ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _OnboardingGlassSurface(
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        radius: 18,
        tintOpacity: .42,
        borderOpacity: .84,
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
    ],
  );
}
