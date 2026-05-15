import 'package:flutter/material.dart';

@immutable
class WorkbenchFileInfoData {
  const WorkbenchFileInfoData({
    required this.sourceRows,
    required this.outputRows,
  });

  final List<String> sourceRows;
  final List<String> outputRows;
}

class WorkbenchFileInfoPanel extends StatelessWidget {
  const WorkbenchFileInfoPanel({super.key, required this.data});

  final WorkbenchFileInfoData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: _FileInfoColumn(title: '源文件信息', rows: data.sourceRows),
          ),
          Container(
            width: 1,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFFE5E5E5),
          ),
          Expanded(
            child: _FileInfoColumn(title: '输出文件信息', rows: data.outputRows),
          ),
        ],
      ),
    );
  }
}

class _FileInfoColumn extends StatelessWidget {
  const _FileInfoColumn({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map((text) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8D8D8D),
                  fontSize: 11,
                  height: 1,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
