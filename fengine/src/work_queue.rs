use std::collections::{HashSet, VecDeque};

use serde::{Deserialize, Serialize};

pub type QueueRevision = u64;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkPriority {
    Background,
    #[default]
    Normal,
    Foreground,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QueuedWork<T> {
    pub work_id: String,
    pub request_id: String,
    pub priority: WorkPriority,
    pub payload: T,
}

#[derive(Debug, Default)]
pub struct WorkQueue<T> {
    entries: VecDeque<QueuedWork<T>>,
    revision: QueueRevision,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReorderError {
    RevisionConflict {
        expected: QueueRevision,
        actual: QueueRevision,
    },
    DuplicateWorkId(String),
    UnknownWorkId(String),
    MissingWorkId(String),
}

impl<T> WorkQueue<T> {
    pub fn new() -> Self {
        Self {
            entries: VecDeque::new(),
            revision: 0,
        }
    }

    pub fn enqueue(&mut self, work: QueuedWork<T>) -> usize {
        let index = self
            .entries
            .iter()
            .position(|queued| queued.priority < work.priority)
            .unwrap_or(self.entries.len());
        self.entries.insert(index, work);
        self.bump_revision();
        index + 1
    }

    pub fn dequeue(&mut self) -> Option<QueuedWork<T>> {
        let work = self.entries.pop_front();
        if work.is_some() {
            self.bump_revision();
        }
        work
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    pub fn position(&self, work_id: &str) -> Option<usize> {
        self.entries
            .iter()
            .position(|work| work.work_id == work_id)
            .map(|index| index + 1)
    }

    pub fn revision(&self) -> QueueRevision {
        self.revision
    }

    pub fn ordered_work_ids(&self) -> Vec<String> {
        self.entries
            .iter()
            .map(|work| work.work_id.clone())
            .collect()
    }

    pub fn entries(&self) -> impl Iterator<Item = &QueuedWork<T>> {
        self.entries.iter()
    }

    pub fn remove(&mut self, work_id: &str) -> Option<QueuedWork<T>> {
        let position = self
            .entries
            .iter()
            .position(|work| work.work_id == work_id)?;
        let work = self.entries.remove(position);
        if work.is_some() {
            self.bump_revision();
        }
        work
    }

    pub fn reorder(
        &mut self,
        expected_revision: QueueRevision,
        ordered_work_ids: &[String],
    ) -> Result<QueueRevision, ReorderError> {
        if expected_revision != self.revision {
            return Err(ReorderError::RevisionConflict {
                expected: expected_revision,
                actual: self.revision,
            });
        }

        let mut requested = HashSet::with_capacity(ordered_work_ids.len());
        for work_id in ordered_work_ids {
            if !requested.insert(work_id.as_str()) {
                return Err(ReorderError::DuplicateWorkId(work_id.clone()));
            }
            if !self.entries.iter().any(|work| work.work_id == *work_id) {
                return Err(ReorderError::UnknownWorkId(work_id.clone()));
            }
        }

        if let Some(missing) = self
            .entries
            .iter()
            .find(|work| !requested.contains(work.work_id.as_str()))
        {
            return Err(ReorderError::MissingWorkId(missing.work_id.clone()));
        }

        let changed = self
            .entries
            .iter()
            .map(|work| work.work_id.as_str())
            .ne(ordered_work_ids.iter().map(String::as_str));
        if !changed {
            return Ok(self.revision);
        }

        let mut remaining = std::mem::take(&mut self.entries);
        let mut reordered = VecDeque::with_capacity(remaining.len());
        for work_id in ordered_work_ids {
            let position = remaining
                .iter()
                .position(|work| work.work_id == *work_id)
                .expect("queue order was validated before mutation");
            reordered.push_back(
                remaining
                    .remove(position)
                    .expect("validated queue entry must still exist"),
            );
        }
        self.entries = reordered;
        self.bump_revision();
        Ok(self.revision)
    }

    fn bump_revision(&mut self) {
        self.revision = self.revision.saturating_add(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn work(id: &str, priority: WorkPriority) -> QueuedWork<()> {
        QueuedWork {
            work_id: id.to_owned(),
            request_id: format!("request-{id}"),
            priority,
            payload: (),
        }
    }

    #[test]
    fn priority_is_stable_and_fifo_within_each_priority() {
        let mut queue = WorkQueue::new();
        queue.enqueue(work("normal-1", WorkPriority::Normal));
        queue.enqueue(work("background", WorkPriority::Background));
        queue.enqueue(work("foreground-1", WorkPriority::Foreground));
        queue.enqueue(work("normal-2", WorkPriority::Normal));
        queue.enqueue(work("foreground-2", WorkPriority::Foreground));

        let order: Vec<_> = std::iter::from_fn(|| queue.dequeue())
            .map(|value| value.work_id)
            .collect();
        assert_eq!(
            order,
            [
                "foreground-1",
                "foreground-2",
                "normal-1",
                "normal-2",
                "background"
            ]
        );
    }

    #[test]
    fn revision_tracks_every_authoritative_queue_mutation() {
        let mut queue = WorkQueue::new();
        assert_eq!(queue.revision(), 0);

        queue.enqueue(work("first", WorkPriority::Normal));
        queue.enqueue(work("second", WorkPriority::Normal));
        assert_eq!(queue.revision(), 2);

        queue.remove("missing");
        assert_eq!(queue.revision(), 2);
        queue.remove("second");
        assert_eq!(queue.revision(), 3);
        queue.dequeue();
        assert_eq!(queue.revision(), 4);
        queue.dequeue();
        assert_eq!(queue.revision(), 4);
    }

    #[test]
    fn reorder_requires_current_revision_and_the_exact_entry_set() {
        let mut queue = WorkQueue::new();
        queue.enqueue(work("first", WorkPriority::Normal));
        queue.enqueue(work("second", WorkPriority::Normal));
        queue.enqueue(work("third", WorkPriority::Normal));
        let revision = queue.revision();

        assert_eq!(
            queue.reorder(
                revision - 1,
                &["third".to_owned(), "second".to_owned(), "first".to_owned()]
            ),
            Err(ReorderError::RevisionConflict {
                expected: revision - 1,
                actual: revision,
            })
        );
        assert_eq!(
            queue.reorder(
                revision,
                &["first".to_owned(), "first".to_owned(), "third".to_owned()]
            ),
            Err(ReorderError::DuplicateWorkId("first".to_owned()))
        );
        assert_eq!(
            queue.reorder(
                revision,
                &["first".to_owned(), "unknown".to_owned(), "third".to_owned()]
            ),
            Err(ReorderError::UnknownWorkId("unknown".to_owned()))
        );
        assert_eq!(
            queue.reorder(revision, &["first".to_owned(), "second".to_owned()]),
            Err(ReorderError::MissingWorkId("third".to_owned()))
        );
        assert_eq!(queue.ordered_work_ids(), ["first", "second", "third"]);

        assert_eq!(
            queue
                .reorder(
                    revision,
                    &["third".to_owned(), "second".to_owned(), "first".to_owned()]
                )
                .unwrap(),
            revision + 1
        );
        assert_eq!(queue.ordered_work_ids(), ["third", "second", "first"]);
    }
}
