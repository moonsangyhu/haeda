import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/friend_data.dart';
import '../providers/friend_provider.dart';

class ContactSearchScreen extends ConsumerStatefulWidget {
  const ContactSearchScreen({super.key});

  @override
  ConsumerState<ContactSearchScreen> createState() =>
      _ContactSearchScreenState();
}

class _ContactSearchScreenState extends ConsumerState<ContactSearchScreen> {
  bool _loading = false;
  bool _permissionDenied = false;
  List<ContactMatchItem>? _matches;
  String? _error;
  final Set<String> _sentRequests = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final granted = await FlutterContacts.requestPermission();
      if (!granted) {
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final phoneNumbers = <String>[];
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          phoneNumbers.add(_normalizePhone(phone.number));
        }
      }

      if (phoneNumbers.isEmpty) {
        setState(() {
          _matches = [];
          _loading = false;
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
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '연락처를 불러오는 중 오류가 발생했어요.';
        _loading = false;
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
      appBar: AppBar(title: const Text('연락처로 친구 찾기')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('연락처에서 친구를 찾고 있어요...'),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contacts, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              const Text(
                '연락처 접근 권한이 필요해요.\n설정에서 권한을 허용해주세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _loadContacts,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadContacts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_matches == null || _matches!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              '연락처에서 가입한 친구를 찾지 못했어요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _matches!.length,
        itemBuilder: (context, index) {
          final match = _matches![index];
          return _buildMatchTile(match, theme);
        },
      ),
    );
  }

  Widget _buildMatchTile(ContactMatchItem match, ThemeData theme) {
    final alreadyFriend = match.friendshipStatus == 'accepted';
    final pending =
        match.friendshipStatus == 'pending' || _sentRequests.contains(match.userId);

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
