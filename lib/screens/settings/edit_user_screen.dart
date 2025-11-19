// lib/screens/edit_user_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

class EditUserScreen extends StatefulWidget {
  const EditUserScreen({super.key});

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  api.User? _currentUser;
  bool _isLoading = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _fetchUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserInfo() async {
    try {
      final sessionApi = api.SessionApi(
        Provider.of<TraccarProvider>(context, listen: false).apiClient,
      );
      final user = await sessionApi.sessionGet();

      if (user != null) {
        setState(() {
          _currentUser = user;
          _nameController.text = user.name ?? '';
          _emailController.text = user.email ?? '';
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('userLoadInfoFailed'.tr),
            ),
          );
        }
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('errorNetwork'.trParams({'error': e.message}))));
      }
    } on api.ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String errorMessage =
            'errorApi'.trParams({'statusCode': e.code.toString(), 'details': e.toString()});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('errorUnexpected'.trParams({'error': e.toString()}))),
        );
      }
    }
  }

  void _logout() {
    final traccarProvider = context.read<TraccarProvider>();
    traccarProvider.clearSessionAndData();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate() && _currentUser != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final apiClient = context.read<TraccarProvider>().apiClient;

        final updatedUser = api.User(
          id: _currentUser!.id,
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : _currentUser!.password,
          readonly: _currentUser!.readonly,
          administrator: _currentUser!.administrator,
          disabled: _currentUser!.disabled,
          deviceLimit: _currentUser!.deviceLimit,
          expirationTime: _currentUser!.expirationTime,
          phone: _currentUser!.phone,
          attributes: _currentUser!.attributes,
          map: _currentUser!.map,
          latitude: _currentUser!.latitude,
          longitude: _currentUser!.longitude,
          zoom: _currentUser!.zoom,
          coordinateFormat: _currentUser!.coordinateFormat,
          userLimit: _currentUser!.userLimit,
          deviceReadonly: _currentUser!.deviceReadonly,
          limitCommands: _currentUser!.limitCommands,
          fixedEmail: _currentUser!.fixedEmail,
          poiLayer: _currentUser!.poiLayer,
        );

        final userPath = '/users/${updatedUser.id}';

        print('tracmi-Updating user info at URL: ${apiClient.basePath}$userPath');
        print('tracmi-Updating user info with body: ${updatedUser.toJson()}');

        final userResponse = await apiClient.invokeAPI(
          userPath,
          'PUT',
          [],
          updatedUser,
          {},
          {},
          'application/json',
        );

        print('tracmi-User info update status code: ${userResponse.statusCode}');
        print('tracmi-User info update response body: ${userResponse.body}');

        if (mounted) {
          final emailChanged = _emailController.text != _currentUser!.email;
          final passwordChanged = _passwordController.text.isNotEmpty;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('userUpdateSuccess'.tr),
            ),
          );

          if (emailChanged || passwordChanged) {
            _logout();
          } else {
            Navigator.pop(context);
          }
        }
      } on api.ApiException catch (e) {
        if (mounted) {
          String errorMessage =
              'errorApi'.trParams({'statusCode': e.code.toString(), 'details': e.toString()});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
            ),
          );
        }
      } on http.ClientException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('errorNetwork'.trParams({'error': e.message}))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('userUpdateFailed'.trParams({'error': e.toString()}))));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _deleteUser() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiClient = context.read<TraccarProvider>().apiClient;
      final userId = _currentUser!.id;
      final userPath = '/users/$userId';
      final headerParams = <String, String>{
        'Content-Type': 'application/json',
      };

      final userResponse = await apiClient.invokeAPI(
        userPath,
        'DELETE',
        [],
        null,
        headerParams,
        {},
        'application/json',
      );

      if (mounted) {
        if (userResponse.statusCode == 204) { // No Content
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('userDeleteSuccess'.tr),
            ),
          );
          _logout(); // Log out and navigate to login screen
        } else {
          String errorMessage = 'userDeleteFailed'.trParams({'statusCode': userResponse.statusCode.toString()});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
            ),
          );
        }
      }
    } on api.ApiException catch (e) {
      if (mounted) {
        String errorMessage = 'errorApi'.trParams({'statusCode': e.code.toString(), 'details': e.toString()});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
          ),
        );
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('errorNetwork'.trParams({'error': e.message}))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('userDeleteFailed'.trParams({'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final TextEditingController confirmEmailController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('userDeleteAccount'.tr),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
               // Text('userConfirmDeletePrompt'.tr),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmEmailController,
                  decoration: InputDecoration(
                    labelText: 'userEmail'.tr,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('sharedCancel'.tr),
              onPressed: () {
                Navigator.of(context).pop();
                // confirmEmailController.dispose();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('sharedRemove'.tr, style: const TextStyle(color: Colors.white)),
              onPressed: () {
                if (confirmEmailController.text == _currentUser?.email) {
                  Navigator.of(context).pop();
                  _deleteUser();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('userEmailMismatch'.tr)),
                  );
                }
                // confirmEmailController.dispose();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settingsUser'.tr)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'sharedName'.tr),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'userEnterName'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'userEmail'.tr),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'userEnterEmail'.tr;
                        }
                        if (!GetUtils.isEmail(value)) {
                          return 'userEnterValidEmail'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'userPassword'.tr,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _updateUser,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text('sharedSave'.tr),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showDeleteConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text('userDeleteAccount'.tr, style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}