import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_bottom_nav.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({
    super.key,
    required this.tradeId,
    required this.workflowController,
  });

  final String tradeId;
  final WorkflowController workflowController;

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  String _selectedZone = '';
  String _meetupTime = '2026-03-08 14:00';
  final TextEditingController _meetupTimeController = TextEditingController();

  // seeded chat so screen looks alive on first open.
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      id: 'msg-1',
      sender: ChatSender.them,
      text: 'hey! condition is great, can we meet near university centre?',
    ),
    const _ChatMessage(
      id: 'msg-2',
      sender: ChatSender.me,
      text: 'works for me, i can do 2:00 pm.',
    ),
  ];

  Trade get _trade {
    return mockTrades
            .where((Trade item) => item.id == widget.tradeId)
            .fold<Trade?>(null, (Trade? _, Trade item) => item) ??
        mockTrades[1];
  }

  @override
  void initState() {
    super.initState();

    final WorkflowState state = widget.workflowController.state;
    final WorkflowTradeState? workflowTrade = state.tradeStates[_trade.id];

    _selectedZone = workflowTrade?.meetupLocation ?? '';
    _meetupTime = workflowTrade?.meetupTime ?? '2026-03-08 14:00';
    _meetupTimeController.text = _meetupTime;

    for (final WorkflowNotification notification in state.notifications.where(
      (WorkflowNotification n) => n.tradeId == _trade.id && !n.read,
    )) {
      widget.workflowController.markNotificationRead(notification.id);
    }
  }

  WorkflowTradeState? _workflowTrade(WorkflowState state) {
    return state.tradeStates[_trade.id];
  }

  String _statusLabel(WorkflowTradeState? workflowTrade) {
    if (workflowTrade == null) {
      return 'Accepted';
    }

    switch (workflowTrade.status) {
      case WorkflowTradeStatus.scheduled:
        return 'Scheduled';
      case WorkflowTradeStatus.ready:
        return 'Ready';
      case WorkflowTradeStatus.completed:
        return 'Completed';
      case WorkflowTradeStatus.pending:
        return 'Pending';
      case WorkflowTradeStatus.accepted:
        return 'Accepted';
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _meetupTime =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      _meetupTimeController.text = _meetupTime;
    });
  }

  void _acceptMeetup() {
    if (_selectedZone.isEmpty || _meetupTime.isEmpty) {
      return;
    }

    widget.workflowController.scheduleMeetup(
      _trade.id,
      _selectedZone,
      _meetupTime,
    );

    final String zoneName =
        campusSafeZones
            .where((SafeZone zone) => zone.id.toString() == _selectedZone)
            .fold<SafeZone?>(null, (SafeZone? _, SafeZone item) => item)
            ?.name ??
        'Selected Safe Zone';

    setState(() {
      _messages.add(
        _ChatMessage(
          id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatSender.system,
          text: 'meetup accepted at $zoneName. status moved to Scheduled.',
        ),
      );
    });
  }

  void _markReady() {
    widget.workflowController.setTradeReady(_trade.id);
    setState(() {
      _messages.add(
        _ChatMessage(
          id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatSender.system,
          text: 'both sides confirmed. this trade is now marked Ready.',
        ),
      );
    });
  }

  @override
  void dispose() {
    _meetupTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workflowController,
      builder: (BuildContext context, Widget? child) {
        final WorkflowState state = widget.workflowController.state;
        final WorkflowTradeState? workflowTrade = _workflowTrade(state);
        final String statusLabel = _statusLabel(workflowTrade);
        final bool canMarkReady =
            statusLabel == 'Scheduled' || statusLabel == 'Accepted';

        return Scaffold(
          bottomNavigationBar: const AppBottomNav(currentRoute: '/trades'),
          body: Column(
            children: <Widget>[
              Container(
                color: const Color(0xFF8B0000),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Command Center (${_trade.id.toUpperCase()})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(statusLabel),
                        backgroundColor: const Color(0xFFFFD700),
                        labelStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: ListTile(
                        title: Text(
                          _trade.listing.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          _trade.offerType == OfferType.trade
                              ? 'Mode: Trade Handshake'
                              : 'Mode: Sale Handshake',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () =>
                              context.push('/listing/${_trade.listingId}'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Live Chat',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            for (final _ChatMessage message in _messages)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: message.sender == ChatSender.me
                                      ? const Color(0x148B0000)
                                      : message.sender == ChatSender.system
                                      ? const Color(0x1A22C55E)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    CircleAvatar(
                                      radius: 11,
                                      child: Text(
                                        message.sender == ChatSender.me
                                            ? 'A'
                                            : message.sender == ChatSender.them
                                            ? 'B'
                                            : '!',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(message.text)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Meetup Planner',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedZone.isEmpty
                                  ? null
                                  : _selectedZone,
                              decoration: const InputDecoration(
                                labelText: 'Safe Zone',
                                border: OutlineInputBorder(),
                              ),
                              items: campusSafeZones
                                  .map(
                                    (SafeZone zone) => DropdownMenuItem<String>(
                                      value: zone.id.toString(),
                                      child: Text(zone.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedZone = value ?? '';
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              readOnly: true,
                              onTap: _pickDateTime,
                              controller: _meetupTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Meetup Time',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_month),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed:
                                  _selectedZone.isEmpty || _meetupTime.isEmpty
                                  ? null
                                  : _acceptMeetup,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF8B0000),
                              ),
                              child: const Text('Accept Meetup'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: canMarkReady ? _markReady : null,
                              child: const Text('Mark as Ready'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum ChatSender { me, them, system }

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
  });

  final String id;
  final ChatSender sender;
  final String text;
}
