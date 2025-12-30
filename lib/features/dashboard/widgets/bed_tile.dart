import 'package:flutter/material.dart';
import '../../../domain/models/patient.dart';
import 'patient_list_card.dart';

class BedTile extends StatefulWidget {
  final int bedNo;
  final Patient? patient;
  final VoidCallback? onTap;

  const BedTile({
    super.key,
    required this.bedNo,
    required this.patient,
    required this.onTap,
  });

  @override
  State<BedTile> createState() => _BedTileState();
}

class _BedTileState extends State<BedTile> {
  @override
  Widget build(BuildContext context) {
    final has = widget.patient != null;

    Color border = const Color(0xFFD1D5DB);
    Color bg = Colors.white;
    bool showDangerBadge = false;

    if (has) {
      final c = statusColor(widget.patient!.status);
      border = c;
      bg = c.withOpacity(0.06);
      showDangerBadge = widget.patient!.status == RiskStatus.danger;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 170;

        final pad = isCompact ? 8.0 : 12.0;
        final iconSize = isCompact ? 28.0 : 34.0;
        final gap1 = isCompact ? 6.0 : 8.0;
        final gap2 = isCompact ? 6.0 : 8.0;

        final bedTextStyle = TextStyle(
          color: const Color(0xFF6B7280),
          fontWeight: FontWeight.w800,
          fontSize: isCompact ? 12 : 13,
        );

        final nameStyle = TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: isCompact ? 13 : 14,
          height: 1.1,
        );

        final ageStyle = TextStyle(
          color: const Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
          fontSize: isCompact ? 11 : 12,
          height: 1.1,
        );

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.6),
            ),
            child: Stack(
              children: [
                if (showDangerBadge)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 10,
                        vertical: isCompact ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: isCompact ? 12 : 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '위험',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: isCompact ? 11 : 12,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Column(
                  children: [
                    const Spacer(),

                    Icon(Icons.bed_outlined, size: iconSize, color: const Color(0xFF6B7280)),
                    SizedBox(height: gap1),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('침대 ${widget.bedNo}', style: bedTextStyle),
                    ),

                    SizedBox(height: gap2),

                    if (has) ...[
                      Icon(Icons.person_outline, size: isCompact ? 14 : 16, color: const Color(0xFF6B7280)),
                      SizedBox(height: isCompact ? 4 : 6),

                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          widget.patient!.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),

                      SizedBox(height: isCompact ? 2 : 4),

                      Text(
                        '${widget.patient!.age}세',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ageStyle,
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      SizedBox(height: isCompact ? 10 : 18),
                      const Text(
                        '비어있음',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
