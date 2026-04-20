// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class SidebarWidget extends StatefulWidget {
  final EditorController ctrl;
  const SidebarWidget({super.key, required this.ctrl});
  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double>   _width;

  bool _filesOpen   = true;
  bool _outlineOpen = true;
  bool _statsOpen   = false;

  // Inline rename state
  String? _renamingId;
  final _renameCtrl = TextEditingController();

  EditorController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _width = Tween<double>(begin: 0, end: 240).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
    if (ctrl.sidebarOpen) _ac.forward();
  }

  @override
  void didUpdateWidget(covariant SidebarWidget old) {
    super.didUpdateWidget(old);
    ctrl.sidebarOpen ? _ac.forward() : _ac.reverse();
  }

  @override
  void dispose() {
    _ac.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }

  // ── Context menu ───────────────────────────────────────────────────────────
  void _showNodeMenu(BuildContext context, TreeNode node, Offset pos) {
    final items = <PopupMenuEntry<String>>[];

    if (node.isFile) {
      items.addAll([
        _menuItem('open',   Icons.open_in_new_outlined,  'Open'),
        _menuItem('rename', Icons.edit_outlined,          'Rename'),
        _menuItem('dup',    Icons.copy_outlined,          'Duplicate'),
        _menuItem('split',  Icons.vertical_split_outlined,'Open in Split'),
        const PopupMenuDivider(),
        _menuItem('delete', Icons.delete_outline,         'Delete', color: T.red),
      ]);
    } else {
      items.addAll([
        _menuItem('newfile',   Icons.insert_drive_file_outlined, 'New File'),
        _menuItem('newfolder', Icons.create_new_folder_outlined, 'New Folder'),
        _menuItem('rename',    Icons.edit_outlined,              'Rename'),
        const PopupMenuDivider(),
        _menuItem('delete',    Icons.delete_outline,             'Delete', color: T.red),
      ]);
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: items,
      color: T.surface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: T.border2),
      ),
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case 'open':
          if (node.fileId != null) ctrl.switchFile(node.fileId!);
        case 'split':
          if (node.fileId != null) ctrl.openSplit(node.fileId!);
        case 'rename':
          setState(() {
            _renamingId = node.id;
            _renameCtrl.text = node.name;
          });
        case 'dup':
          if (node.fileId != null) _duplicateFile(node);
        case 'newfile':
          _promptCreate(context, isFile: true, parentId: node.id);
        case 'newfolder':
          _promptCreate(context, isFile: false, parentId: node.id);
        case 'delete':
          _confirmDelete(context, node);
      }
    });
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color? color}) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          Icon(icon, size: 14, color: color ?? T.textMid),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: color ?? T.text, fontSize: 12.5)),
        ]),
      );

  void _duplicateFile(TreeNode node) {
    if (node.fileId == null) return;
    final orig = ctrl.files.firstWhere((f) => f.id == node.fileId!,
        orElse: () => ctrl.activeFile);
    final parts = orig.name.split('.');
    final ext   = parts.length > 1 ? '.${parts.last}' : '';
    final base  = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('.') : parts.first;
    ctrl.createFileInTree('$base copy$ext', parentNodeId: node.parentId);
    final newFile = ctrl.files.last;
    ctrl.ctrlFor(newFile.id).text = orig.content;
  }

  void _promptCreate(BuildContext ctx, {required bool isFile, String? parentId}) {
    final textCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: T.surface,
        title: Text(isFile ? 'New File' : 'New Folder',
            style: TextStyle(color: T.text, fontSize: 14)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: TextStyle(color: T.text, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: isFile ? 'filename.js' : 'folder-name',
            hintStyle: TextStyle(color: T.textDim),
            filled: true, fillColor: T.bg2,
            border: OutlineInputBorder(borderSide: BorderSide(color: T.border2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onSubmitted: (name) {
            Navigator.pop(ctx);
            if (name.trim().isEmpty) return;
            if (isFile) {
              ctrl.createFileInTree(name.trim(), parentNodeId: parentId);
            } else {
              ctrl.createFolder(name.trim(), parentNodeId: parentId);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: T.textDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final name = textCtrl.text.trim();
              if (name.isEmpty) return;
              if (isFile) {
                ctrl.createFileInTree(name, parentNodeId: parentId);
              } else {
                ctrl.createFolder(name, parentNodeId: parentId);
              }
            },
            child: Text('Create', style: TextStyle(color: T.accent)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, TreeNode node) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: T.surface,
        title: Text('Delete ${node.isFolder ? "Folder" : "File"}?',
            style: TextStyle(color: T.text, fontSize: 14)),
        content: Text(
          'Delete "${node.name}"${node.isFolder ? " and all its contents" : ""}?',
          style: TextStyle(color: T.textMid, fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: T.textDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.deleteNode(node.id);
            },
            child: Text('Delete', style: TextStyle(color: T.red)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _width,
      builder: (_, __) {
        if (_width.value == 0) return const SizedBox.shrink();
        return ClipRect(
          child: SizedBox(
            width: _width.value,
            child: SizedBox(
              width: 240,
              child: Container(
                decoration: BoxDecoration(
                  color: T.bg2,
                  border: Border(right: BorderSide(color: T.border)),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── FILE TREE ────────────────────────────────────────
                    _SbSection(
                      'FILES', _filesOpen,
                      () => setState(() => _filesOpen = !_filesOpen),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _IconBtn(Icons.create_new_folder_outlined, () =>
                            _promptCreate(context, isFile: false)),
                        _IconBtn(Icons.add, () =>
                            _promptCreate(context, isFile: true)),
                      ]),
                      children: [
                        if (ctrl.treeNodes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No files',
                                style: TextStyle(color: T.textDim, fontSize: 11)),
                          )
                        else
                          ..._buildTree(ctrl.treeNodes, depth: 0),
                      ],
                    ),

                    // ── OUTLINE ──────────────────────────────────────────
                    _SbSection(
                      'OUTLINE', _outlineOpen,
                      () => setState(() => _outlineOpen = !_outlineOpen),
                      children: ctrl.outlineItems.isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                                child: Text('No symbols',
                                    style: TextStyle(color: T.textDim, fontSize: 11)),
                              ),
                            ]
                          : ctrl.outlineItems.map((item) => GestureDetector(
                                onTap: () => ctrl.goToLine(item.line),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 5, 16, 5),
                                  child: Row(children: [
                                    Text(item.kind,
                                        style: TextStyle(
                                            color: item.color,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(item.label,
                                          style: TextStyle(
                                              color: T.textMid,
                                              fontSize: 11.5,
                                              fontFamily: 'monospace'),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('${item.line}',
                                        style: TextStyle(
                                            color: T.textFaint, fontSize: 10)),
                                  ]),
                                ),
                              )).toList(),
                    ),

                    // ── STATS ────────────────────────────────────────────
                    _SbSection(
                      'STATS', _statsOpen,
                      () => setState(() => _statsOpen = !_statsOpen),
                      children: [
                        Builder(builder: (_) {
                          final (l, c, w) = ctrl.currentStats;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatRow('Lines', '$l'),
                                _StatRow('Chars', '$c'),
                                _StatRow('Words', '$w'),
                                _StatRow('Lang',  ctrl.activeFile.lang.displayName),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tree rendering ─────────────────────────────────────────────────────────
  List<Widget> _buildTree(List<TreeNode> nodes, {required int depth}) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      widgets.add(_buildNode(node, depth: depth));
      if (node.isFolder && node.expanded) {
        widgets.addAll(_buildTree(node.children, depth: depth + 1));
      }
    }
    return widgets;
  }

  Widget _buildNode(TreeNode node, {required int depth}) {
    final isActive = node.fileId != null && node.fileId == ctrl.activeId;
    final indent   = 12.0 + depth * 14.0;

    // Inline rename
    if (_renamingId == node.id) {
      return Padding(
        padding: EdgeInsets.fromLTRB(indent + 20, 2, 8, 2),
        child: SizedBox(
          height: 26,
          child: TextField(
            controller: _renameCtrl,
            autofocus:  true,
            style: TextStyle(
                color: T.text, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true, fillColor: T.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: OutlineInputBorder(
                  borderSide: BorderSide(color: T.accent), borderRadius: BorderRadius.circular(4)),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: T.border), borderRadius: BorderRadius.circular(4)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: T.accent), borderRadius: BorderRadius.circular(4)),
              isDense: true,
            ),
            onSubmitted: (name) {
              if (name.trim().isNotEmpty) ctrl.renameNode(node.id, name.trim());
              setState(() => _renamingId = null);
            },
            onEditingComplete: () => setState(() => _renamingId = null),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (node.isFile && node.fileId != null) {
          ctrl.switchFile(node.fileId!);
        } else if (node.isFolder) {
          ctrl.toggleFolder(node.id);
        }
      },
      onLongPressStart: (d) => _showNodeMenu(context, node, d.globalPosition),
      child: Container(
        height: 30,
        padding: EdgeInsets.only(left: indent, right: 8),
        color: isActive ? T.accentDim : Colors.transparent,
        child: Row(children: [
          // Expand arrow for folders
          if (node.isFolder)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                node.expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 16, color: T.textDim,
              ),
            )
          else
            const SizedBox(width: 4),

          // Icon
          Icon(
            _nodeIcon(node),
            size: 13,
            color: node.isFolder ? T.yellow : _fileColor(node),
          ),
          const SizedBox(width: 6),

          // Name
          Expanded(
            child: Text(
              node.name,
              style: TextStyle(
                color:      isActive ? T.text : T.textMid,
                fontSize:   12,
                fontFamily: 'monospace',
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Dirty indicator for files
          if (node.fileId != null)
            Builder(builder: (_) {
              final f = ctrl.files.where((f) => f.id == node.fileId).firstOrNull;
              if (f?.dirty == true) {
                return Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: T.orange, shape: BoxShape.circle),
                );
              }
              return const SizedBox.shrink();
            }),
        ]),
      ),
    );
  }

  IconData _nodeIcon(TreeNode node) {
    if (node.isFolder) {
      return node.expanded ? Icons.folder_open_outlined : Icons.folder_outlined;
    }
    final ext = node.name.split('.').lastOrNull ?? '';
    return switch (ext) {
      'html' => Icons.html_outlined,
      'css'  => Icons.css_outlined,
      'js'   => Icons.javascript_outlined,
      'dart' => Icons.code_outlined,
      'json' => Icons.data_object_outlined,
      'md'   => Icons.article_outlined,
      _      => Icons.insert_drive_file_outlined,
    };
  }

  Color _fileColor(TreeNode node) {
    if (node.fileId == null) return T.textDim;
    final f = ctrl.files.where((f) => f.id == node.fileId).firstOrNull;
    return f?.lang.color ?? T.textDim;
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SbSection extends StatelessWidget {
  final String       title;
  final bool         open;
  final VoidCallback onToggle;
  final List<Widget> children;
  final Widget?      trailing;
  const _SbSection(this.title, this.open, this.onToggle,
      {required this.children, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: onToggle,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: T.border))),
          child: Row(children: [
            Icon(
              open ? Icons.expand_less : Icons.chevron_right,
              size: 14, color: T.textDim,
            ),
            const SizedBox(width: 4),
            Text(title,
                style: TextStyle(
                  color: T.textDim, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
      if (open) ...children,
    ],
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Icon(icon, size: 14, color: T.textDim),
    ),
  );
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text('$label: ',
          style: TextStyle(color: T.textDim, fontSize: 11.5, fontFamily: 'monospace')),
      Text(value,
          style: TextStyle(color: T.textMid, fontSize: 11.5, fontFamily: 'monospace')),
    ]),
  );
}
