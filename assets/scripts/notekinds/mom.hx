function opponentNoteEventPre(e:NoteEvent) {
	if (e.type == 'hit' && e.note.noteKind == 'mom')
		e.animSuffix = '-alt';
}