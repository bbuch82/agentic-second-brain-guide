# Tasks Dashboard
#dashboard #tasks

> This dashboard shows all tasks across the vault using the Obsidian Tasks Plugin.
> **Rule:** Every task must have the `#todo` tag.

---

## Overdue / Urgent
```tasks
not done
tags include #todo
(due before today) OR (priority is high)
```

## Today & This Week
```tasks
not done
tags include #todo
due before in one week
sort by due
```

---

## Work: Wanderly
```tasks
not done
tags include #todo
path includes 20_Projects/Wanderly
group by function task.file.filename
```

## Work: Atlas AI
```tasks
not done
tags include #todo
path includes 20_Projects/Wanderly/Atlas
group by function task.file.filename
```

## Private Life
```tasks
not done
tags include #todo
path includes 30_Life
group by function task.file.filename
```

---

## The "Lost & Found"
> Tasks that live somewhere unexpected (Inbox, Network, or misfiled).
```tasks
not done
tags include #todo
path does not include 20_Projects
path does not include 30_Life
tags does not include #article
group by path
```

---

## Reading List
```tasks
not done
tags include #article
group by path
```
