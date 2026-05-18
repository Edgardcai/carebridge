import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/care_store.dart';
import '../domain/models.dart';

class CareShell extends StatelessWidget {
  const CareShell({
    required this.currentIndex,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final Widget child;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.tasks,
    AppRoutes.log,
    AppRoutes.family,
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit CareBridge?'),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (index == currentIndex) {
              return;
            }
            Navigator.of(context).pushReplacementNamed(_routes[index]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_turned_in_outlined),
              selectedIcon: Icon(Icons.assignment_turned_in),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined),
              selectedIcon: Icon(Icons.history_edu),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.family_restroom_outlined),
              selectedIcon: Icon(Icons.family_restroom),
              label: 'Family',
            ),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1100), _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goNext() {
    if (!mounted || _navigated) {
      return;
    }
    final store = context.read<CareStore>();
    if (store.isLoading) {
      _timer = Timer(const Duration(milliseconds: 200), _goNext);
      return;
    }
    _navigated = true;
    final route = !store.legalAccepted
        ? AppRoutes.legal
        : !store.isSignedIn
            ? AppRoutes.auth
            : store.patients.isEmpty
                ? AppRoutes.patientNew
                : AppRoutes.home;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.monitor_heart,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CareBridge',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'From discharge instructions to daily recovery actions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.policy, size: 56, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Before you start',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CareBridge helps you and your family track recovery tasks, reminders, and symptoms in one place.',
            ),
            const SizedBox(height: 16),
            const _NoticeCard(
              icon: Icons.info_outline,
              title: 'Important notice',
              body:
                  'CareBridge is a logging and reminder tool. It is not a substitute for professional medical advice, diagnosis, or treatment. In an emergency, contact your doctor or local emergency services immediately.',
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I have read and understand'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _accepted
                  ? () {
                      context.read<CareStore>().acceptLegal();
                      Navigator.of(context)
                          .pushReplacementNamed(AppRoutes.auth);
                    }
                  : null,
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Full disclaimer'),
                  content: const Text(
                    'This coursework MVP is for reminders, logging, and family coordination only. It does not interpret symptoms, recommend treatment, or replace clinician instructions.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              child: const Text('View full disclaimer'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(text: 'demo@carebridge.local');
  final _password = TextEditingController(text: 'carebridge');
  final _confirmPassword = TextEditingController();
  bool _isLogin = true;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty) {
      _showSnack(context, 'Email is required');
      return;
    }
    if (password.isEmpty) {
      _showSnack(context, 'Password is required');
      return;
    }
    if (!_isLogin && password != _confirmPassword.text) {
      _showSnack(context, 'Passwords do not match');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await context.read<CareStore>().signInDemo(
            email: _email.text,
            password: password,
            createAccount: !_isLogin,
          );
      if (!mounted) {
        return;
      }
      final store = context.read<CareStore>();
      Navigator.of(context).pushReplacementNamed(
        store.patients.isEmpty ? AppRoutes.patientNew : AppRoutes.home,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(context, _authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _authErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('operation-not-allowed')) {
      return 'Email/password login is not enabled in Firebase Authentication.';
    }
    if (message.contains('network-request-failed') ||
        message.contains('TimeoutException')) {
      return 'Network timeout. Check phone internet access and try again.';
    }
    if (message.contains('wrong-password') ||
        message.contains('invalid-credential')) {
      return 'Email or password is incorrect. Try Sign up for a new account.';
    }
    if (message.contains('email-already-in-use')) {
      return 'This email already exists. Switch to Log in.';
    }
    if (message.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (message.contains('permission-denied')) {
      return 'Firestore denied this request. Check Firebase rules.';
    }
    return 'Sign in failed: $message';
  }

  void _showForgotPasswordInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password reset'),
        content: const Text(
          'Password reset will be available after Firebase Auth is connected. For this MVP, use the test account to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _submit();
            },
            child: const Text('Use test account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.favorite, size: 56, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'CareBridge',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your partner in the recovery journey.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Log in')),
                ButtonSegment(value: false, label: Text('Sign up')),
              ],
              selected: {_isLogin},
              onSelectionChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _isLogin = value.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon:
                      Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassword,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordInfo,
                child: const Text('Forgot password?'),
              ),
            ),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLogin ? 'Log in' : 'Create account'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: const Text('Continue with test account'),
            ),
            const SizedBox(height: 24),
            const _MicroDisclaimer(),
          ],
        ),
      ),
    );
  }
}

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final patients = store.patients;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TopRow(
          title: 'Patients',
          trailing: IconButton(
            tooltip: 'Add patient',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.patientNew),
            icon: const Icon(Icons.add),
          ),
        ),
        const SizedBox(height: 12),
        if (patients.isEmpty)
          _EmptyState(
            icon: Icons.person_add_alt,
            title: 'Add your first patient',
            body: 'Create a profile to start building a recovery plan.',
            actionLabel: 'New patient',
            onAction: () =>
                Navigator.of(context).pushNamed(AppRoutes.patientNew),
          )
        else
          ...patients.map(
            (patient) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: _InitialAvatar(patient.fullName),
                  title: Text(
                    patient.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${patient.conditionCategory} - Day ${patient.daySinceDischarge(DateTime.now())} since discharge',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.read<CareStore>().selectPatient(patient.id);
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushReplacementNamed(AppRoutes.home);
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({this.patientId, super.key});

  final String? patientId;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController(text: '65');
  final _department = TextEditingController(text: 'Orthopedics');
  final _contactName = TextEditingController(text: 'Sarah Lee');
  final _contactPhone = TextEditingController(text: '+852 5555 0101');
  String _category = 'Post-op Recovery';
  late DateTime _dischargeDate;

  @override
  void initState() {
    super.initState();
    final store = context.read<CareStore>();
    final patient = widget.patientId == null
        ? store.blankPatient()
        : store.patients.firstWhere((item) => item.id == widget.patientId);
    _name.text = patient.fullName;
    _age.text = patient.age?.toString() ?? '';
    _department.text = patient.mainDepartment;
    _contactName.text = patient.emergencyContact.name;
    _contactPhone.text = patient.emergencyContact.phone;
    _category = patient.conditionCategory.isEmpty
        ? _category
        : patient.conditionCategory;
    _dischargeDate = patient.dischargeDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _department.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showSnack(context, 'Patient name is required');
      return;
    }
    final store = context.read<CareStore>();
    final now = DateTime.now();
    final patient = PatientProfile(
      id: widget.patientId ?? '',
      ownerUid: store.user?.uid ?? 'demo_user_1',
      fullName: _name.text.trim(),
      age: int.tryParse(_age.text.trim()),
      dischargeDate: _dischargeDate,
      conditionCategory: _category,
      mainDepartment: _department.text.trim(),
      emergencyContact: EmergencyContact(
        name: _contactName.text.trim(),
        relationship: 'Family',
        phone: _contactPhone.text.trim(),
      ),
      createdAt: now,
      updatedAt: now,
    );
    await store.savePatient(patient);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientId == null ? 'New patient' : 'Edit profile'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(icon: Icons.person, title: 'Patient profile'),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
                icon: Icons.medical_information, title: 'Clinical details'),
            _PickerTile(
              icon: Icons.calendar_month,
              label: 'Date of discharge',
              value: formatDate(_dischargeDate),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  initialDate: _dischargeDate,
                );
                if (picked != null) {
                  setState(() => _dischargeDate = picked);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration:
                  const InputDecoration(labelText: 'Condition category'),
              items: const [
                DropdownMenuItem(
                    value: 'Post-op Recovery', child: Text('Post-op Recovery')),
                DropdownMenuItem(
                    value: 'Post-op Knee', child: Text('Post-op Knee')),
                DropdownMenuItem(
                    value: 'Cardiovascular', child: Text('Cardiovascular')),
                DropdownMenuItem(
                    value: 'Orthopedic', child: Text('Orthopedic')),
                DropdownMenuItem(
                    value: 'Neurological', child: Text('Neurological')),
                DropdownMenuItem(
                    value: 'Respiratory', child: Text('Respiratory')),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _department,
              decoration: const InputDecoration(labelText: 'Main department'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
                icon: Icons.contact_phone, title: 'Emergency contact'),
            TextField(
              controller: _contactName,
              decoration: const InputDecoration(labelText: 'Contact name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.call_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save patient'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final patient = store.selectedPatient;

    if (store.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (patient == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _EmptyState(
            icon: Icons.person_add_alt,
            title: 'Let us set up your recovery plan',
            body: 'Create a patient profile before adding tasks or logs.',
            actionLabel: 'Create profile',
            onAction: () =>
                Navigator.of(context).pushNamed(AppRoutes.patientNew),
          ),
        ),
      );
    }

    final upcoming = store.pendingTasks.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PatientHeader(patient: patient),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.pending_actions,
                label: "Today's pending",
                value: '${store.todayPending.length}',
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle,
                label: "Today's done",
                value: '${store.todayDone.length}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Up next',
          actionLabel: 'View all',
          onAction: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.tasks),
        ),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const _NoticeCard(
            icon: Icons.task_alt,
            title: 'No pending tasks',
            body: 'Everything scheduled for now is complete.',
          )
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) =>
                  _UpcomingTaskCard(task: upcoming[index]),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: upcoming.length,
            ),
          ),
        const SizedBox(height: 20),
        _AppointmentCard(task: store.nextAppointment),
        const SizedBox(height: 20),
        _SectionTitle(title: 'Quick actions'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.85,
          children: [
            _ActionTile(
              icon: Icons.add_task,
              label: 'Add task',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.taskForm),
            ),
            _ActionTile(
              icon: Icons.document_scanner_outlined,
              label: 'Scan doc',
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .pushNamed(AppRoutes.scanReview),
            ),
            _ActionTile(
              icon: Icons.monitor_heart,
              label: 'Log symptoms',
              onTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.log),
            ),
            _ActionTile(
              icon: Icons.group_outlined,
              label: 'Family',
              onTap: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.family),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _MicroDisclaimer(),
      ],
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskStatus _status = TaskStatus.pending;
  TaskType? _type;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    var visible = _tasksForStatus(store, _status);
    if (_type != null) {
      visible = visible.where((task) => task.type == _type).toList();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TopRow(
          title: 'Daily tasks',
          trailing: IconButton(
            tooltip: 'Add task',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.taskForm),
            icon: const Icon(Icons.add),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: TaskStatus.values
              .map(
                (status) => ChoiceChip(
                  label: Text(
                      '${status.label} (${_tasksForStatus(store, status).length})'),
                  selected: _status == status,
                  labelStyle: _chipTextStyle(_status == status),
                  onSelected: (_) => setState(() => _status = status),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _type == null,
              labelStyle: _chipTextStyle(_type == null),
              onSelected: (_) => setState(() => _type = null),
            ),
            ...TaskType.values.map(
              (type) => ChoiceChip(
                label: Text(type.label),
                selected: _type == type,
                labelStyle: _chipTextStyle(_type == type),
                onSelected: (_) => setState(() => _type = type),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          _EmptyState(
            icon: _status == TaskStatus.missed
                ? Icons.task_alt
                : Icons.inbox_outlined,
            title: _status == TaskStatus.missed
                ? 'Nothing missed - great job'
                : 'No ${_status.label.toLowerCase()} tasks',
            body: 'Your recovery plan will show matching tasks here.',
            actionLabel: 'Add task',
            onAction: () => Navigator.of(context).pushNamed(AppRoutes.taskForm),
          )
        else
          ...visible.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskTile(task: task),
            ),
          ),
      ],
    );
  }

  List<CareTask> _tasksForStatus(CareStore store, TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return store.todayPending;
      case TaskStatus.completed:
        return store.todayDone;
      case TaskStatus.missed:
        return store.needsAttentionTasks;
    }
  }
}

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final task = store.taskById(taskId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task detail')),
        body: const Center(child: Text('Task not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task detail'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.taskForm,
              arguments: TaskFormArgs(taskId: task.id),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeIcon(type: task.type),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        _StatusChip(status: task.status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _DetailRow(
                      icon: Icons.info_outline,
                      label: 'Instructions',
                      value: task.details.isEmpty
                          ? 'No details added.'
                          : task.details,
                    ),
                    _DetailRow(
                      icon: Icons.schedule,
                      label: 'Reminder',
                      value: _taskScheduleSummary(task),
                    ),
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Assigned to',
                      value: task.assigneeName,
                    ),
                    if (task.sourceLabel != null)
                      _DetailRow(
                        icon: Icons.document_scanner_outlined,
                        label: 'Source',
                        value: '${task.sourceLabel}\nAdded via OCR scan',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (task.status == TaskStatus.pending)
              FilledButton.icon(
                onPressed: () async {
                  await context
                      .read<CareStore>()
                      .markTaskStatus(task.id, TaskStatus.completed);
                  if (context.mounted) {
                    _showSnack(context, 'Marked as completed');
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark as completed'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({this.taskId, super.key});

  final String? taskId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  late TaskType _type;
  late RepeatRule _repeat;
  late DateTime _date;
  late TimeOfDay _time;
  late String _assigneeId;
  int _advanceMinutes = 0;
  int _durationDays = 7;
  List<TimeOfDay> _dailyTimes = const [];

  @override
  void initState() {
    super.initState();
    final store = context.read<CareStore>();
    final task = widget.taskId == null
        ? store.blankTask()
        : store.taskById(widget.taskId!)!;
    _title.text = task.title;
    _details.text = task.details;
    _type = task.type;
    _repeat = task.repeatRule;
    _date = task.scheduledAt;
    _time = TimeOfDay.fromDateTime(task.scheduledAt);
    _durationDays =
        task.repeatRule.isRepeating ? task.normalizedRepeatDurationDays : 7;
    _dailyTimes = _timesFromTask(task);
    _assigneeId = task.assigneeId ?? 'unassigned';
    _advanceMinutes = task.remindMinutesBefore;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _showSnack(context, 'Task title is required');
      return;
    }
    final store = context.read<CareStore>();
    final existing =
        widget.taskId == null ? null : store.taskById(widget.taskId!);
    final patient = store.selectedPatient;
    if (patient == null) {
      _showSnack(context, 'Create a patient first');
      return;
    }
    final member =
        _assigneeId == 'unassigned' ? null : store.memberById(_assigneeId);
    final now = DateTime.now();
    final reminderTimes = _normalizedReminderTimes();
    final firstTime = reminderTimes.first;
    final normalizedScheduledAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      firstTime.hour,
      firstTime.minute,
    );
    final task = CareTask(
      id: existing?.id ?? '',
      patientId: patient.id,
      title: _title.text.trim(),
      details: _details.text.trim(),
      type: _type,
      status: existing?.status ?? TaskStatus.pending,
      scheduledAt: normalizedScheduledAt,
      repeatRule: _repeat,
      repeatDurationDays: _repeat.isRepeating ? _durationDays : 1,
      reminderMinutesOfDay: _repeat.isMultiDaily
          ? reminderTimes.map(_minutesFromTime).toList(growable: false)
          : const [],
      remindMinutesBefore: _advanceMinutes,
      assigneeId: member?.id,
      assigneeName: member?.displayName ?? 'Unassigned',
      sourceLabel: existing?.sourceLabel,
      sourceImageUrl: existing?.sourceImageUrl,
      completedAt: existing?.completedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await store.saveTask(task);
    if (!mounted) {
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.tasks, (route) => false);
  }

  List<TimeOfDay> _timesFromTask(CareTask task) {
    final values = task.normalizedReminderMinutesOfDay;
    if (!task.repeatRule.isMultiDaily) {
      return [TimeOfDay.fromDateTime(task.scheduledAt)];
    }
    return values.map(_timeFromMinutes).toList(growable: false);
  }

  List<TimeOfDay> _normalizedReminderTimes() {
    if (!_repeat.isMultiDaily) {
      return [_time];
    }
    final target = _repeat.timesPerActiveDay;
    final next = [..._dailyTimes];
    if (next.isEmpty) {
      next.add(_time);
    }
    while (next.length < target) {
      next.add(_suggestTime(next.length, next.first));
    }
    final unique = <int, TimeOfDay>{};
    for (final time in next) {
      unique[_minutesFromTime(time)] = time;
    }
    final sorted = unique.values.toList()
      ..sort((a, b) => _minutesFromTime(a).compareTo(_minutesFromTime(b)));
    return sorted.take(target).toList(growable: false);
  }

  void _setRepeat(RepeatRule rule) {
    setState(() {
      _repeat = rule;
      if (_repeat.isMultiDaily) {
        _dailyTimes = _defaultTimesFor(rule);
        _time = _dailyTimes.first;
      } else {
        _dailyTimes = [_time];
      }
    });
  }

  List<TimeOfDay> _defaultTimesFor(RepeatRule rule) {
    switch (rule) {
      case RepeatRule.twiceDaily:
        return const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 20, minute: 0),
        ];
      case RepeatRule.threeTimesDaily:
        return const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 14, minute: 0),
          TimeOfDay(hour: 20, minute: 0),
        ];
      case RepeatRule.none:
      case RepeatRule.daily:
      case RepeatRule.everyTwoDays:
      case RepeatRule.everyThreeDays:
      case RepeatRule.weekly:
        return [_time];
    }
  }

  TimeOfDay _suggestTime(int index, TimeOfDay base) {
    final baseMinutes = _minutesFromTime(base);
    final minutes = (baseMinutes + index * 6 * 60) % (24 * 60);
    return _timeFromMinutes(minutes);
  }

  int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _timeFromMinutes(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  @override
  Widget build(BuildContext context) {
    final members = context.watch<CareStore>().familyMembers;

    return Scaffold(
      appBar:
          AppBar(title: Text(widget.taskId == null ? 'New task' : 'Edit task')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(icon: Icons.category_outlined, title: 'Task type'),
            Wrap(
              spacing: 8,
              children: TaskType.values
                  .map(
                    (type) => ChoiceChip(
                      avatar: Icon(iconForTask(type), size: 18),
                      label: Text(type.label),
                      selected: _type == type,
                      labelStyle: _chipTextStyle(_type == type),
                      onSelected: (_) => setState(() => _type = type),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.schedule, title: 'Schedule'),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: formatDate(_date),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _date,
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule,
                    label: 'Time',
                    value: _time.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) {
                        setState(() {
                          _time = picked;
                          if (_repeat.isMultiDaily) {
                            final next = [..._dailyTimes];
                            if (next.isEmpty) {
                              next.add(picked);
                            } else {
                              next[0] = picked;
                            }
                            _dailyTimes = next;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RepeatRule>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat task'),
              items: RepeatRule.values
                  .map((rule) =>
                      DropdownMenuItem(value: rule, child: Text(rule.label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _setRepeat(value);
                }
              },
            ),
            if (_repeat.isRepeating) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _durationDays,
                decoration:
                    const InputDecoration(labelText: 'Reminder duration'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day')),
                  DropdownMenuItem(value: 3, child: Text('3 days')),
                  DropdownMenuItem(value: 5, child: Text('5 days')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 10, child: Text('10 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                  DropdownMenuItem(value: 21, child: Text('21 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                ],
                onChanged: (value) =>
                    setState(() => _durationDays = value ?? _durationDays),
              ),
            ],
            if (_repeat.isMultiDaily) ...[
              const SizedBox(height: 12),
              _SectionHeader(
                  icon: Icons.alarm_add_outlined,
                  title: 'Daily reminder times'),
              const SizedBox(height: 8),
              ..._normalizedReminderTimes().asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PickerTile(
                        icon: Icons.access_time,
                        label: 'Time ${entry.key + 1}',
                        value: entry.value.format(context),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: entry.value,
                          );
                          if (picked == null) {
                            return;
                          }
                          setState(() {
                            final next = _normalizedReminderTimes();
                            next[entry.key] = picked;
                            next.sort((a, b) => _minutesFromTime(a)
                                .compareTo(_minutesFromTime(b)));
                            _dailyTimes = next;
                            _time = next.first;
                          });
                        },
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _advanceMinutes,
              decoration: const InputDecoration(labelText: 'Remind in advance'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('At time of event')),
                DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                DropdownMenuItem(value: 60, child: Text('1 hour before')),
                DropdownMenuItem(value: 1440, child: Text('1 day before')),
              ],
              onChanged: (value) =>
                  setState(() => _advanceMinutes = value ?? 0),
            ),
            const SizedBox(height: 20),
            _SectionHeader(icon: Icons.group_outlined, title: 'Assign to'),
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Family member'),
              items: [
                const DropdownMenuItem(
                    value: 'unassigned', child: Text('Anyone')),
                ...members.map(
                  (member) => DropdownMenuItem(
                    value: member.id,
                    child:
                        Text('${member.displayName} (${member.relationship})'),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _assigneeId = value ?? 'unassigned'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save task')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class OcrReviewScreen extends StatefulWidget {
  const OcrReviewScreen({super.key});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  List<OcrCandidate> _candidates = const [];
  final _picker = ImagePicker();
  bool _isScanning = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _candidates =
        List<OcrCandidate>.from(context.read<CareStore>().ocrCandidates);
  }

  Future<void> _scanDocument(ImageSource source) async {
    final patient = context.read<CareStore>().selectedPatient;
    if (patient == null) {
      _showSnack(context, 'Create/select a patient first');
      return;
    }
    try {
      final image = await _picker.pickImage(source: source);
      if (!mounted) {
        return;
      }
      if (image == null) {
        _showSnack(context, 'No image selected');
        return;
      }
      setState(() => _isScanning = true);
      final count = await context
          .read<CareStore>()
          .scanOcrCandidatesFromImage(image.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates =
            List<OcrCandidate>.from(context.read<CareStore>().ocrCandidates);
      });
      _showSnack(context, 'Scanned $count candidate rows');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        context,
        'Open scan failed. Please check camera/photo permission and try again. Details: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CareStore>();
    final selectedCount = _candidates.where((item) => item.selected).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () async {
            final nav = Navigator.of(context, rootNavigator: true);
            if (await nav.maybePop()) {
              return;
            }
            nav.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
          },
        ),
        title: const Text('Review scan'),
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: () => _showSnack(
                context, 'OCR results must be reviewed before saving.'),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 6,
        color: AppColors.surfaceWhite,
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$selectedCount items selected',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: selectedCount == 0 || _isCreating
                        ? null
                        : () async {
                            setState(() => _isCreating = true);
                            final nav =
                                Navigator.of(context, rootNavigator: true);
                            try {
                              final count = await context
                                  .read<CareStore>()
                                  .createTasksFromOcr(_candidates);
                              if (!context.mounted) {
                                return;
                              }
                              setState(() => _candidates = const []);
                              _showSnack(context, 'Added $count tasks to plan');
                              nav.pushNamedAndRemoveUntil(
                                  AppRoutes.tasks, (_) => false);
                            } finally {
                              if (mounted) {
                                setState(() => _isCreating = false);
                              }
                            }
                          },
                    icon: _isCreating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isCreating ? 'Creating...' : 'Create tasks'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _NoticeCard(
            icon: Icons.check_circle,
            title: 'Review scan results',
            body:
                'Use Camera or Gallery to read a discharge note. Confirm lines below before creating tasks.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _scanDocument(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_isScanning ? 'Scanning...' : 'Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _scanDocument(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Container(
              height: 156,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner,
                      size: 44, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'Discharge sheet example',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('Choose one image with clear text.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._candidates.asMap().entries.map(
                (entry) => _OcrCandidateCard(
                  candidate: entry.value,
                  onChanged: (candidate) {
                    setState(() => _candidates[entry.key] = candidate);
                  },
                ),
              ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pushNamed(AppRoutes.taskForm),
            icon: const Icon(Icons.add),
            label: const Text('Add another task manually'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class SymptomLogScreen extends StatefulWidget {
  const SymptomLogScreen({super.key});

  @override
  State<SymptomLogScreen> createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends State<SymptomLogScreen> {
  late int _pain;
  late TextEditingController _temp;
  late TextEditingController _notes;
  late List<String> _photoUrls;
  final List<String> _newPhotoPaths = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final log = context.read<CareStore>().todayLog;
    _pain = log?.painLevel ?? 4;
    _temp = TextEditingController(
        text: (log?.temperatureC ?? 36.8).toStringAsFixed(1));
    _notes = TextEditingController(text: log?.notes ?? '');
    _photoUrls = [...?log?.photoUrls];
  }

  @override
  void dispose() {
    _temp.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<CareStore>().saveSymptomLog(
          date: DateTime.now(),
          painLevel: _pain,
          temperatureC: double.tryParse(_temp.text.trim()) ?? 36.8,
          notes: _notes.text.trim(),
          preservedPhotoUrls: _photoUrls,
          localPhotoPaths: _newPhotoPaths,
        );
    _newPhotoPaths.clear();
    if (mounted) {
      _showSnack(context, 'Saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<CareStore>().lastSevenLogs;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TopRow(
          title: 'Today',
          subtitle: formatDate(DateTime.now()),
          trailing: IconButton(
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                    icon: Icons.monitor_heart, title: 'Pain level'),
                Center(
                  child: Text(
                    '$_pain',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Slider(
                  value: _pain.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '$_pain',
                  onChanged: (value) => setState(() => _pain = value.round()),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 (No pain)',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text('10 (Severe)',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _temp,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Temperature',
            suffixText: 'C',
            prefixIcon: Icon(Icons.device_thermostat),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.edit_note),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                    icon: Icons.photo_camera_outlined,
                    title: 'Visual progress'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await _picker.pickImage(
                            source: ImageSource.gallery);
                        if (picked == null) {
                          return;
                        }
                        setState(() => _newPhotoPaths.add(picked.path));
                      },
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_a_photo),
                      ),
                    ),
                    ..._photoUrls.asMap().entries.map(
                          (entry) => _SymptomPhotoThumb(
                            imagePath: entry.value,
                            onRemove: () =>
                                setState(() => _photoUrls.removeAt(entry.key)),
                          ),
                        ),
                    ..._newPhotoPaths.asMap().entries.map(
                          (entry) => _SymptomPhotoThumb(
                            imagePath: entry.value,
                            pending: true,
                            onRemove: () => setState(
                                () => _newPhotoPaths.removeAt(entry.key)),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'Past 7 days',
          actionLabel: 'Timeline',
          onAction: () => Navigator.of(context).pushNamed(AppRoutes.timeline),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: MiniTrendChart(logs: logs),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save entry'),
        ),
      ],
    );
  }
}

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final logs = store.symptomLogs;

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery timeline')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Review daily progress and symptoms.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.sentiment_dissatisfied_outlined,
                    label: 'Avg pain (7d)',
                    value: store.avgPain7d.toStringAsFixed(1),
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.thermostat,
                    label: 'Max temp',
                    value: store.maxTemp7d.toStringAsFixed(1),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (logs.isEmpty)
              const _EmptyState(
                icon: Icons.history_edu,
                title: 'No logs yet',
                body: 'Saved symptom entries will appear here.',
              )
            else
              ...logs.map((log) => _TimelineTile(log: log)),
          ],
        ),
      ),
    );
  }
}

class FamilyHubScreen extends StatelessWidget {
  const FamilyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();
    final members = store.familyMembers;
    final done = store.todayDone.length;
    final overdue = store.needsAttentionTasks.length;
    final remaining = store.todayPending.length;
    final total = done + remaining;
    final completion = total == 0 ? 0 : ((done / total) * 100).round();
    final latest = store.symptomLogs.isEmpty ? null : store.symptomLogs.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TopRow(
          title: 'Family hub',
          trailing: IconButton(
            tooltip: 'Invite family',
            onPressed: () => _showSnack(
                context, 'Firebase invite hook is reserved for role B.'),
            icon: const Icon(Icons.person_add_alt),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: CircularProgressIndicator(
                        value: completion / 100,
                        strokeWidth: 10,
                        backgroundColor: AppColors.surfaceContainer,
                      ),
                    ),
                    Text(
                      '$completion%',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MiniStat(
                          label: 'Completed',
                          value: '$done',
                          color: AppColors.success),
                      _MiniStat(
                          label: 'Remaining',
                          value: '$remaining',
                          color: AppColors.warning),
                      _MiniStat(
                          label: 'Needs attention',
                          value: '$overdue',
                          color: AppColors.danger),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (store.needsAttentionTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Needs attention'),
          const SizedBox(height: 8),
          ...store.needsAttentionTasks
              .take(2)
              .map((task) => _TaskTile(task: task, compact: true)),
        ],
        const SizedBox(height: 16),
        const _SectionTitle(title: 'Team progress'),
        const SizedBox(height: 8),
        ...members.map((member) {
          final assigned = store.tasks
              .where((task) => task.assigneeId == member.id)
              .toList();
          final completed = assigned
              .where((task) => task.status == TaskStatus.completed)
              .length;
          final ratio = assigned.isEmpty ? 0.0 : completed / assigned.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _InitialAvatar(member.displayName),
                title: Text(member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$completed/${assigned.length} tasks - ${member.relationship}'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: ratio),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (latest != null)
          _NoticeCard(
            icon: Icons.monitor_heart,
            title: 'Latest log',
            body:
                'Pain ${latest.painLevel}/10, temp ${latest.temperatureC.toStringAsFixed(1)}C. ${latest.notes}',
          ),
        const SizedBox(height: 12),
        const _MicroDisclaimer(),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CareStore>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _TopRow(
            title: 'Settings', subtitle: 'Manage preferences and account.'),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: store.notificationsEnabled,
                onChanged: store.setNotificationsEnabled,
                secondary: const Icon(Icons.medication_outlined),
                title: const Text('Medication reminders'),
                subtitle: const Text('Uses on-device reminders when enabled.'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: store.notificationsEnabled,
                onChanged: store.setNotificationsEnabled,
                secondary: const Icon(Icons.calendar_today_outlined),
                title: const Text('Visit alerts'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Send instant test notification'),
                subtitle: const Text(
                  'Should appear immediately in notification shade.',
                ),
                onTap: () async {
                  final ok = await store.showInstantTestLocalNotification();
                  if (!context.mounted) {
                    return;
                  }
                  _showSnack(
                    context,
                    ok
                        ? 'Sent instant test notification.'
                        : 'Local notifications are not configured.',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.schedule_send_outlined),
                title: const Text('Test reminder in 5 seconds'),
                subtitle: const Text(
                  'Use this to verify notification permission and alarms. Put the app in the background after tapping.',
                ),
                onTap: () async {
                  final ok = await store.scheduleTestLocalNotification();
                  if (!context.mounted) {
                    return;
                  }
                  _showSnack(
                    context,
                    ok
                        ? 'Scheduled test reminder. Check the notification shade in ~5s.'
                        : 'Local notifications are not configured.',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            value: store.largeText,
            onChanged: store.setLargeText,
            secondary: const Icon(Icons.text_increase),
            title: const Text('Large text'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Disclaimer'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Disclaimer'),
                    content: const Text(
                      'CareBridge is a reminder and logging tool. It does not provide medical advice.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text('Data and privacy'),
                subtitle: Text(
                    'Firebase storage and sharing rules are reserved for role B.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text(
                  'You will return to the login screen. Unsaved changes on this page will be lost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) {
              return;
            }
            await context.read<CareStore>().signOut();
            if (context.mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.auth, (route) => false);
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'CareBridge v1.0.0 (MVP)',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class MiniTrendChart extends StatelessWidget {
  const MiniTrendChart({required this.logs, super.key});

  final List<SymptomLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('No symptom data yet'));
    }
    final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    final points =
        sorted.length > 14 ? sorted.sublist(sorted.length - 14) : sorted;
    final hasSameDayEntries = _hasSameDayEntries(points);
    final tempMin =
        points.map((log) => log.temperatureC).reduce((a, b) => a < b ? a : b);
    final tempMax =
        points.map((log) => log.temperatureC).reduce((a, b) => a > b ? a : b);
    final rightMin = (tempMin - 0.4).clamp(34.0, 42.0);
    final rightMax = (tempMax + 0.4).clamp(34.0, 42.0);
    final tempSpan =
        (rightMax - rightMin).abs() < 0.001 ? 1.0 : (rightMax - rightMin);

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, points.length - 1).toDouble(),
              minY: 0,
              maxY: 10,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: Color(0xFFE0E7E4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xFFE0E7E4)),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: points.length <= 8 ? 1 : 2,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if ((value - i).abs() > 0.01 ||
                          i < 0 ||
                          i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final d = points[i].date;
                      final label = hasSameDayEntries
                          ? _compactTime(d)
                          : '${d.month}/${d.day}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                rightTitles: AxisTitles(
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('Temp C', style: TextStyle(fontSize: 10)),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: 2,
                    getTitlesWidget: (value, meta) => Text(
                      (rightMin + (value / 10) * tempSpan).toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 168,
                  getTooltipColor: (_) => const Color(0xFF334155),
                  getTooltipItems: (spots) => spots.map((spot) {
                    final index = spot.x.round().clamp(0, points.length - 1);
                    final log = points[index];
                    final style = TextStyle(
                      color:
                          spot.barIndex == 0 ? Colors.white : AppColors.warning,
                      fontWeight: FontWeight.w800,
                    );
                    if (spot.barIndex == 0) {
                      return LineTooltipItem(
                        'Pain ${log.painLevel}/10\n${formatDate(log.date)} ${formatTime(log.date)}',
                        style,
                      );
                    }
                    return LineTooltipItem(
                      'Temp ${log.temperatureC.toStringAsFixed(1)} C',
                      style,
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].painLevel.toDouble()),
                  ],
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.10),
                  ),
                ),
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(
                        i.toDouble(),
                        (((points[i].temperatureC - rightMin) / tempSpan) * 10)
                            .clamp(0.0, 10.0)
                            .toDouble(),
                      ),
                  ],
                  isCurved: true,
                  color: AppColors.warning,
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                  dashArray: const [6, 3],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.primary, label: 'Pain'),
            SizedBox(width: 16),
            _LegendDot(color: AppColors.warning, label: 'Temp'),
          ],
        ),
      ],
    );
  }

  bool _hasSameDayEntries(List<SymptomLog> points) {
    final seen = <String>{};
    for (final log in points) {
      final key = '${log.date.year}-${log.date.month}-${log.date.day}';
      if (seen.contains(key)) return true;
      seen.add(key);
    }
    return false;
  }

  String _compactTime(DateTime date) {
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.hour}:$minute';
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SymptomPhotoThumb extends StatelessWidget {
  const _SymptomPhotoThumb({
    required this.imagePath,
    required this.onRemove,
    this.pending = false,
  });

  final String imagePath;
  final VoidCallback onRemove;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final isNetworkImage =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: (isNetworkImage
              ? Image.network(
                  imagePath,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildBrokenImage(),
                )
              : Image.file(
                  File(imagePath),
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildBrokenImage(),
                )),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
        if (pending)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.black54,
              child: const Text(
                'Pending',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrokenImage() {
    return Container(
      width: 84,
      height: 84,
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});

  final PatientProfile patient;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.patients),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          patient.fullName,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                  Text(
                    'Day ${patient.daySinceDischarge(DateTime.now())} of recovery',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          icon: const Icon(Icons.account_circle_outlined, size: 32),
        ),
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTaskCard extends StatelessWidget {
  const _UpcomingTaskCard({required this.task});

  final CareTask task;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.taskDetail,
            arguments: task.id,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeIcon(type: task.type, compact: true),
                    const Spacer(),
                    _StatusChip(status: task.status),
                  ],
                ),
                const Spacer(),
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_taskTimeSummary(task)} - ${task.assigneeName}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.task});

  final CareTask? task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: task == null
            ? Row(
                children: [
                  const Icon(Icons.calendar_month,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('No follow-up visit scheduled')),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.taskForm),
                    child: const Text('Add'),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Next appointment',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(task!.title),
                        Text(
                          '${formatDate(task!.scheduledAt)}, ${_taskTimeSummary(task!)}',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    this.compact = false,
  });

  final CareTask task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isMissed = task.status == TaskStatus.missed;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.taskDetail,
          arguments: task.id,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMissed)
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 16),
                  child: Row(
                    children: [
                      _TypeIcon(type: task.type),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_taskTimeSummary(task)} - ${task.details}',
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Assigned to ${task.assigneeName}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (task.status == TaskStatus.pending)
                        IconButton(
                          tooltip: 'Mark complete',
                          onPressed: () => context
                              .read<CareStore>()
                              .markTaskStatus(task.id, TaskStatus.completed),
                          icon: const Icon(Icons.check_circle_outline),
                        )
                      else
                        _StatusChip(status: task.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcrCandidateCard extends StatelessWidget {
  const _OcrCandidateCard({
    required this.candidate,
    required this.onChanged,
  });

  final OcrCandidate candidate;
  final ValueChanged<OcrCandidate> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _OcrTypeChip(type: candidate.type),
                  const Spacer(),
                  Text('${(candidate.confidence * 100).round()}%'),
                  Checkbox(
                    value: candidate.selected,
                    onChanged: (value) => onChanged(
                      candidate.copyWith(selected: value ?? false),
                    ),
                  ),
                ],
              ),
              TextFormField(
                initialValue: candidate.extractedText,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Extracted text'),
                onChanged: (value) =>
                    onChanged(candidate.copyWith(extractedText: value)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<OcrCandidateType>(
                initialValue: candidate.type,
                decoration: const InputDecoration(labelText: 'Detected type'),
                items: const [
                  DropdownMenuItem(
                    value: OcrCandidateType.medication,
                    child: Text('Medication'),
                  ),
                  DropdownMenuItem(
                    value: OcrCandidateType.appointment,
                    child: Text('Appointment'),
                  ),
                  DropdownMenuItem(
                    value: OcrCandidateType.instruction,
                    child: Text('Instruction'),
                  ),
                  DropdownMenuItem(
                    value: OcrCandidateType.other,
                    child: Text('Other'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onChanged(candidate.copyWith(type: value));
                  }
                },
              ),
              if (candidate.scheduledAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Parsed time: ${formatDate(candidate.scheduledAt!)} ${formatTime(candidate.scheduledAt!)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.log});

  final SymptomLog log;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          leading:
              const Icon(Icons.radio_button_checked, color: AppColors.primary),
          title: Text(
            '${formatDate(log.date)} at ${formatTime(log.date)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Pain ${log.painLevel}/10 - Temp ${log.temperatureC.toStringAsFixed(1)}C',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(log.notes)),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(value, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({
    required this.type,
    this.compact = false,
  });

  final TaskType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorForTask(type).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconForTask(type),
          color: colorForTask(type), size: compact ? 18 : 22),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return CircleAvatar(
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      foregroundColor: AppColors.primaryDark,
      child: Text(initials.isEmpty ? '?' : initials),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorForStatus(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: colorForStatus(status),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OcrTypeChip extends StatelessWidget {
  const _OcrTypeChip({required this.type});

  final OcrCandidateType type;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_ocrIcon(type), size: 18),
      label: Text(_ocrLabel(type)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MicroDisclaimer extends StatelessWidget {
  const _MicroDisclaimer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'CareBridge is a reminder and logging tool. It does not provide medical advice.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

IconData iconForTask(TaskType type) {
  switch (type) {
    case TaskType.medication:
      return Icons.medication_outlined;
    case TaskType.visit:
      return Icons.local_hospital_outlined;
    case TaskType.rehab:
      return Icons.directions_walk;
    case TaskType.note:
      return Icons.note_alt_outlined;
  }
}

Color colorForTask(TaskType type) {
  switch (type) {
    case TaskType.medication:
      return AppColors.primary;
    case TaskType.visit:
      return AppColors.secondary;
    case TaskType.rehab:
      return AppColors.success;
    case TaskType.note:
      return AppColors.warning;
  }
}

Color colorForStatus(TaskStatus status) {
  switch (status) {
    case TaskStatus.pending:
      return AppColors.warning;
    case TaskStatus.completed:
      return AppColors.success;
    case TaskStatus.missed:
      return AppColors.danger;
  }
}

TextStyle _chipTextStyle(bool selected) => TextStyle(
      color: selected ? AppColors.primaryDark : AppColors.textPrimary,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
    );

String _taskTimeSummary(CareTask task) {
  final times = task.normalizedReminderMinutesOfDay
      .map((minute) => _formatMinutesAsTime(minute))
      .toList(growable: false);
  if (times.length <= 2) {
    return times.join(', ');
  }
  return '${times.take(2).join(', ')} +${times.length - 2}';
}

String _taskScheduleSummary(CareTask task) {
  final lines = <String>[
    'Starts ${formatDate(task.scheduledAt)} at ${_taskTimeSummary(task)}',
    task.repeatRule.isRepeating
        ? '${task.repeatRule.label} for ${task.normalizedRepeatDurationDays} days'
        : 'One-time reminder',
    'Alert: ${_advanceLabel(task.remindMinutesBefore)}',
  ];
  if (task.repeatRule.isMultiDaily) {
    lines.insert(1, 'Times: ${_taskTimeSummary(task)}');
  }
  return lines.join('\n');
}

String _advanceLabel(int minutes) {
  switch (minutes) {
    case 0:
      return 'At time of event';
    case 15:
      return '15 minutes before';
    case 30:
      return '30 minutes before';
    case 60:
      return '1 hour before';
    case 1440:
      return '1 day before';
    default:
      return '$minutes minutes before';
  }
}

String _formatMinutesAsTime(int minutes) {
  final hour24 = (minutes ~/ 60) % 24;
  final minute = minutes % 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
}

IconData _ocrIcon(OcrCandidateType type) {
  switch (type) {
    case OcrCandidateType.medication:
      return Icons.medication_outlined;
    case OcrCandidateType.appointment:
      return Icons.calendar_today_outlined;
    case OcrCandidateType.instruction:
      return Icons.directions_walk;
    case OcrCandidateType.other:
      return Icons.note_alt_outlined;
  }
}

String _ocrLabel(OcrCandidateType type) {
  switch (type) {
    case OcrCandidateType.medication:
      return 'Meds';
    case OcrCandidateType.appointment:
      return 'Visit';
    case OcrCandidateType.instruction:
      return 'Activity';
    case OcrCandidateType.other:
      return 'Other';
  }
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
