import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_search_service.dart';
import '../../../../core/location/mock_location_search_service.dart';
import '../../domain/entities/birth_location.dart';
import '../../data/models/birth_profile_model.dart';
import '../providers/birth_profile_provider.dart';

class BirthProfilePage extends ConsumerStatefulWidget {
  const BirthProfilePage({super.key});

  @override
  ConsumerState<BirthProfilePage> createState() => _BirthProfilePageState();
}

class _BirthProfilePageState extends ConsumerState<BirthProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _placeController = TextEditingController();

  final LocationSearchService _locationService = MockLocationSearchService();

  Timer? _searchTimer;

  String? _selectedGender;
  DateTime? _dateOfBirth;
  TimeOfDay? _birthTime;
  BirthLocation? _selectedLocation;

  List<BirthLocation> _suggestions = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _nameController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  void _onPlaceChanged(String value) {
    _searchTimer?.cancel();

    setState(() {
      _selectedLocation = null;
    });

    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _searching = true;
      });

      final results = await _locationService.search(value);

      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _selectLocation(BirthLocation location) {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _selectedLocation = location;
      _placeController.text = location.displayName;
      _suggestions = [];
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _dateOfBirth = selected;
      });
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _birthTime = selected;
      });
    }
  }

  Future<void> _continue() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGender == null) {
      _showMessage('Please select gender');
      return;
    }

    if (_dateOfBirth == null) {
      _showMessage('Please select date of birth');
      return;
    }

    if (_birthTime == null) {
      _showMessage('Please select birth time');
      return;
    }

    if (_selectedLocation == null) {
      _showMessage('Please select a birth location from the suggestions');
      return;
    }

    debugPrint('========== BIRTH PROFILE ==========');
    debugPrint('Name: ${_nameController.text}');
    debugPrint('Gender: $_selectedGender');
    debugPrint('DOB: $_dateOfBirth');
    debugPrint('Time: $_birthTime');
    debugPrint('Location: ${_selectedLocation!.displayName}');
    debugPrint('Latitude: ${_selectedLocation!.latitude}');
    debugPrint('Longitude: ${_selectedLocation!.longitude}');
    debugPrint('Timezone: ${_selectedLocation!.timezone}');
    debugPrint('===================================');

    final profile = BirthProfileModel(
      name: _nameController.text.trim(),
      gender: _selectedGender!,
      dateOfBirth: _dateOfBirth!,
      birthTime: _birthTime!.format(context),
      location: _selectedLocation!,
    );

    await ref.read(birthProfileProvider.notifier).saveProfile(profile);

    if (!mounted) return;

    context.go('/home');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Birth Profile'), centerTitle: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create your birth profile',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accurate birth details help us create your personalized astrology experience.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),

                _sectionTitle(context, 'Basic Information'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameController,
                  enabled: true,
                  readOnly: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.person_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),

                const SizedBox(height: 28),

                _sectionTitle(context, 'Birth Details'),
                const SizedBox(height: 12),

                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dateOfBirth == null
                          ? 'Select date'
                          : '${_dateOfBirth!.month.toString().padLeft(2, '0')}/'
                                '${_dateOfBirth!.day.toString().padLeft(2, '0')}/'
                                '${_dateOfBirth!.year}',
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: _selectTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Exact Birth Time',
                      prefixIcon: Icon(Icons.access_time_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _birthTime == null
                          ? 'Select time'
                          : _birthTime!.format(context),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                _sectionTitle(context, 'Place of Birth'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _placeController,
                  enabled: true,
                  readOnly: false,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.search,
                  onChanged: _onPlaceChanged,
                  decoration: InputDecoration(
                    labelText: 'Place of Birth',
                    hintText: 'Search city',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your place of birth';
                    }

                    if (_selectedLocation == null) {
                      return 'Please select a location from the suggestions';
                    }

                    return null;
                  },
                ),

                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: _suggestions.map((location) {
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(location.city),
                          subtitle: Text(location.displayName),
                          onTap: () {
                            _selectLocation(location);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],

                if (_selectedLocation != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Location',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text(_selectedLocation!.displayName),
                          const SizedBox(height: 8),
                          Text(
                            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}',
                          ),
                          Text(
                            'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                          ),
                          Text('Timezone: ${_selectedLocation!.timezone}'),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _continue,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
