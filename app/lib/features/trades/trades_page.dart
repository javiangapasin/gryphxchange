import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_bottom_nav.dart';
import '../../models/mock_data.dart';
import '../../services/workflow/workflow_controller.dart';
import '../../services/workflow/workflow_state.dart';

class TradesPage extends StatefulWidget {
  const TradesPage({super.key, required this.workflowController});

  final WorkflowController workflowController;

  @override
  State<TradesPage> createState() => _TradesPageState();
}

class _TradesPageState extends State<TradesPage> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workflowController,
      builder: (BuildContext context, Widget? child) {
        final WorkflowState workflowState = widget.workflowController.state;

        // tiny adapter so old mock status + new workflow status stay in sync.
        final List<_EnhancedTrade> enhancedTrades = mockTrades
            .map((Trade trade) {
              final WorkflowTradeState? workflowTrade =
                  workflowState.tradeStates[trade.id];
              return _EnhancedTrade(
                trade: trade,
                workflowStatus:
                    workflowTrade?.status ?? _mapLegacyStatus(trade.status),
                workflowMode:
                    workflowTrade?.mode ??
                    (trade.offerType == OfferType.trade
                        ? TransactionMode.trade
                        : TransactionMode.sale),
              );
            })
            .toList(growable: false);

        final List<_EnhancedTrade> pendingTrades = enhancedTrades
            .where(
              (trade) => trade.workflowStatus == WorkflowTradeStatus.pending,
            )
            .toList(growable: false);

        final List<_EnhancedTrade> activeTrades = enhancedTrades
            .where(
              (trade) =>
                  trade.workflowStatus == WorkflowTradeStatus.accepted ||
                  trade.workflowStatus == WorkflowTradeStatus.scheduled ||
                  trade.workflowStatus == WorkflowTradeStatus.ready,
            )
            .toList(growable: false);

        final List<_EnhancedTrade> completedTrades = enhancedTrades
            .where(
              (trade) => trade.workflowStatus == WorkflowTradeStatus.completed,
            )
            .toList(growable: false);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            bottomNavigationBar: const AppBottomNav(currentRoute: '/trades'),
            body: Column(
              children: <Widget>[
                Container(
                  color: const Color(0xFF8B0000),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                  child: const SafeArea(
                    bottom: false,
                    child: Text(
                      'Active Trades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TabBar(
                  labelColor: const Color(0xFF8B0000),
                  indicatorColor: const Color(0xFF8B0000),
                  tabs: <Widget>[
                    Tab(text: 'Pending (${pendingTrades.length})'),
                    Tab(text: 'Active (${activeTrades.length})'),
                    Tab(text: 'Completed (${completedTrades.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _TradesList(
                        trades: pendingTrades,
                        emptyTitle: 'No pending trades',
                        emptySubtitle:
                            'once offers start rolling in, they show here.',
                      ),
                      _TradesList(
                        trades: activeTrades,
                        emptyTitle: 'No active trades',
                        emptySubtitle:
                            'accepted or scheduled trades will show up here.',
                      ),
                      _TradesList(
                        trades: completedTrades,
                        emptyTitle: 'No completed trades',
                        emptySubtitle: 'finished handshakes will move here.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TradesList extends StatelessWidget {
  const _TradesList({
    required this.trades,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<_EnhancedTrade> trades;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                emptyTitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emptySubtitle,
                style: const TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trades.length,
      itemBuilder: (BuildContext context, int index) {
        final _EnhancedTrade trade = trades[index];
        final String statusLabel = _statusLabel(trade.workflowStatus);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    trade.trade.listing.images.first,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        trade.trade.listing.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trade.trade.listing.seller.name,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          Chip(
                            label: Text(
                              trade.workflowMode == TransactionMode.trade
                                  ? 'Trade Flow'
                                  : 'Sale Flow',
                            ),
                            backgroundColor: const Color(0x1A8B0000),
                            labelStyle: const TextStyle(
                              color: Color(0xFF8B0000),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(statusLabel),
                            backgroundColor: _statusChipColor(
                              trade.workflowStatus,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton(
                            onPressed: () =>
                                context.push('/command/${trade.trade.id}'),
                            child: const Text('Open Command Center'),
                          ),
                          FilledButton(
                            onPressed: () => context.push(
                              '/listing/${trade.trade.listingId}',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF8B0000),
                            ),
                            child: const Text('View Listing'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(WorkflowTradeStatus status) {
    switch (status) {
      case WorkflowTradeStatus.scheduled:
        return 'Scheduled';
      case WorkflowTradeStatus.ready:
        return 'Ready';
      case WorkflowTradeStatus.accepted:
        return 'Accepted';
      case WorkflowTradeStatus.pending:
        return 'Pending';
      case WorkflowTradeStatus.completed:
        return 'Completed';
    }
  }

  Color _statusChipColor(WorkflowTradeStatus status) {
    if (status == WorkflowTradeStatus.completed) {
      return const Color(0x2E22C55E);
    }
    if (status == WorkflowTradeStatus.pending) {
      return const Color(0xFFFFECB3);
    }
    return const Color(0xFFD1FAE5);
  }
}

class _EnhancedTrade {
  const _EnhancedTrade({
    required this.trade,
    required this.workflowStatus,
    required this.workflowMode,
  });

  final Trade trade;
  final WorkflowTradeStatus workflowStatus;
  final TransactionMode workflowMode;
}

WorkflowTradeStatus _mapLegacyStatus(TradeStatus status) {
  switch (status) {
    case TradeStatus.pending:
      return WorkflowTradeStatus.pending;
    case TradeStatus.accepted:
      return WorkflowTradeStatus.accepted;
    case TradeStatus.completed:
      return WorkflowTradeStatus.completed;
    case TradeStatus.rejected:
      // no rejected state in workflow yet, so we map it to accepted for now.
      return WorkflowTradeStatus.accepted;
  }
}
