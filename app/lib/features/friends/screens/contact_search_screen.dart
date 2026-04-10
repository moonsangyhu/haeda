import 'package:flutter/material.dart';
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
  bool _loading = false;
  List<ContactMatchItem>? _matches;
  String? _error;
  final Set<String> _sentRequests = {};

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return;

    final normalized = _normalizePhone(raw);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/friends/contact-match',
        data: {
          'phone_numbers': [normalized],
        },
      );
      final data =
          ContactMatchData.fromJson(response.data as Map<String, dynamic>);
      setState(() {
        _matches = data.matches;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '검색 중 오류가 발생했어요.';
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
      appBar: AppBar(title: const Text('친구 찾기')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
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
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
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
        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
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
              '전화번호로 친구를 검색해보세요',
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
