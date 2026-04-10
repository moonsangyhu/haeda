import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_contacts/models/contact/contact_property.dart';
import 'package:flutter_contacts/models/permissions/permission_status.dart';
import 'package:flutter_contacts/models/permissions/permission_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/friend_data.dart';

class ContactSearchScreen extends ConsumerStatefulWidget {
  const ContactSearchScreen({super.key});

  @override
  ConsumerState<ContactSearchScreen> createState() =>
      _ContactSearchScreenState();
}

class _ContactSearchScreenState extends ConsumerState<ContactSearchScreen> {
  final _phoneController = TextEditingController();
  bool _contactsLoading = false;
  bool _searchLoading = false;
  List<ContactMatchItem>? _matches;
  String? _error;
  final Set<String> _sentRequests = {};

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// 기기 연락처에서 친구 찾기
  Future<void> _loadFromContacts() async {
    setState(() {
      _contactsLoading = true;
      _error = null;
    });

    try {
      final status = await FlutterContacts.permissions
          .request(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연락처 접근 권한이 필요해요.')),
          );
        }
        setState(() => _contactsLoading = false);
        return;
      }

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      final phoneNumbers = <String>[];
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          phoneNumbers.add(_normalizePhone(phone.number));
        }
      }

      if (phoneNumbers.isEmpty) {
        setState(() {
          _matches = [];
          _contactsLoading = false;
        });
        return;
      }

      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/friends/contact-match',
        data: {'phone_numbers': phoneNumbers},
      );
      final data =
          ContactMatchData.fromJson(response.data as Map<String, dynamic>);
      setState(() {
        _matches = data.matches;
        _contactsLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '연락처를 불러오는 중 오류가 발생했어요.';
        _contactsLoading = false;
      });
    }
  }

  /// 전화번호 직접 입력으로 검색
  Future<void> _searchByPhone() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _searchLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/friends/contact-match',
        data: {
          'phone_numbers': [_normalizePhone(raw)],
        },
      );
      final data =
          ContactMatchData.fromJson(response.data as Map<String, dynamic>);
      setState(() {
        _matches = data.matches;
        _searchLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '검색 중 오류가 발생했어요.';
        _searchLoading = false;
      });
    }
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('0')) {
      return '+82${digits.substring(1)}';
    }
    if (!digits.startsWith('+')) {
      return '+82$digits';
    }
    return digits;
  }

  Future<void> _sendRequest(String userId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/friends/requests', data: {'addressee_id': userId});
      setState(() => _sentRequests.add(userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 보냈어요!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청을 보내지 못했어요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 찾기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // 연락처에서 찾기 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _contactsLoading ? null : _loadFromContacts,
                icon: _contactsLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.contacts),
                label: Text(
                  _contactsLoading ? '연락처에서 찾는 중...' : '연락처에서 친구 찾기',
                ),
              ),
            ),
          ),

          // 구분선 + 직접 검색
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '또는 직접 검색',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),

          // 전화번호 입력
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '전화번호를 입력하세요',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _searchByPhone(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _searchLoading ? null : _searchByPhone,
                  child: _searchLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('검색'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadFromContacts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_matches == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '연락처에서 자동으로 찾거나\n전화번호로 직접 검색해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_matches!.isEmpty) {
      return const Center(child: Text('검색 결과가 없어요.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _matches!.length,
      itemBuilder: (context, index) {
        final match = _matches![index];
        return _buildMatchTile(match, theme);
      },
    );
  }

  Widget _buildMatchTile(ContactMatchItem match, ThemeData theme) {
    final alreadyFriend = match.friendshipStatus == 'accepted';
    final pending = match.friendshipStatus == 'pending' ||
        _sentRequests.contains(match.userId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withAlpha(51),
        backgroundImage: match.profileImageUrl != null
            ? NetworkImage(match.profileImageUrl!)
            : null,
        child: match.profileImageUrl == null
            ? Text(
                match.nickname.isNotEmpty ? match.nickname[0] : '?',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Text(match.nickname),
      trailing: alreadyFriend
          ? Chip(
              label: const Text('친구'),
              backgroundColor: theme.colorScheme.primaryContainer,
            )
          : pending
              ? const Chip(label: Text('요청됨'))
              : FilledButton.tonal(
                  onPressed: () => _sendRequest(match.userId),
                  child: const Text('친구 요청'),
                ),
    );
  }
}
