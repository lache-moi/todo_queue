import json
import datetime
from NicePrinter import table

TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
TASK_CATEGORY_ALIASES = {
    "a": "Admin",
    "c": "Cleaning",
    "hw": "Homework",
}

class Task:
    def __init__(self, local_id: int, name: str, priority: int, category: str, time_created: datetime.datetime, description: str = None, set_urgent: datetime.datetime = None):
        self.local_id = local_id
        self.time_created = time_created
        self.name = name
        self.priority = priority
        self.category = category
        self.description = description
        self.set_urgent = set_urgent
        self.prev = None
        self.next = None

    def update_priority(self, new_priority: int):
        self.priority = new_priority

    def get_basic_info(self):
        info = self.get_properties()
        info["priority"] = f"P{info['priority']}"
        for attr in info:
            info[attr] = str(info[attr]) if info[attr] else ""

        return list(info.values())
         
    def __str__(self):
        return json.dumps(self.get_properties())

    def get_properties(self):
        return {
            "local_id": self.local_id,
            "name": self.name,
            "time_created": self.time_created.strftime(TIME_FORMAT),
            "priority": self.priority,
            "category": self.category,
            "description": self.description,
            "set_urgent": self.set_urgent.strftime(TIME_FORMAT) if self.set_urgent else None,
        }

    @staticmethod
    def get_readable_attribute_names():
        return ["Local Id", "Name", "Time Created", "Priority", "Category", "Description", "Set Urgent"]
    @staticmethod
    def get_attribute_names():
        return [attribute.lower().replace(" ", "_") for attribute in Task.get_readable_attribute_names()]

class TodoQueue:
    def __init__(self, infile: str = None):
        self.local_id_counter = 0
        self.ids = {}
        self.head = Task(None, None, None, None, None, None)
        self.tail = Task(None, None, None, None, None, None)
        self.head.next, self.tail.prev = self.tail, self.head

    def increment_counter(self):
        self.local_id_counter += 1
        return self.local_id_counter
    
    def empty(self):
        return not self.ids

    def insert_task_before(self, node, new_task):
        new_task.next, new_task.prev = node, node.prev
        node.prev.next = new_task
        node.prev = new_task
        return new_task

    def remove_task(self, task):
        self.ids.pop(task.local_id)   
        task.prev.next, task.next.prev = task.next, task.prev
        return task        

    def put(self, new_task):
        self.ids[new_task.local_id] = new_task
        for node in self:
            if new_task.priority < node.priority:
                return self.insert_task_before(node, new_task)
        return self.insert_task_before(self.tail, new_task)

    def pull_first(self):
        if not self.empty():
            return self.remove_task(self.head.next)
    
    def pull_given_id(self, local_id):
        if task_to_remove := self.ids.get(local_id):
            return self.remove_task(task_to_remove)

    def __str__(self):
        output = [Task.get_readable_attribute_names()]
        [output.append(task.get_basic_info()) for task in self]
        return table(output, centered = True) + "\n"

    def __iter__(self):
        self.curr_node = self.head
        return self
    
    def __next__(self):
        curr_task = self.curr_node.next
        if curr_task.name:
            self.curr_node = self.curr_node.next
            return curr_task
        raise StopIteration


    
