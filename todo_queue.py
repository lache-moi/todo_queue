import json
import datetime
from NicePrinter import table
from typing import List, Dict

TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
TASK_CATEGORY_ALIASES = {
    "a": "admin",
    "c": "cleaning",
    "hw": "homework",
    "lg": "life goals",
    "r": "routine",
    "s": "shopping",
    "soc": "social",
}
DAYS_TO_ESCALATE = {
    1: 1,
    2: 6,
    3: 21,
    4: 90,
}

class Task:
    
    def __init__(self, local_id: int, name: str, priority: int, category: str, time_created: datetime.datetime, description: str = None, escalate_time: datetime.datetime = None):
        self.local_id = local_id
        self.time_created = time_created
        self.name = name
        self.priority = priority
        self.category = category
        self.description = description
        self.escalate_time = escalate_time if escalate_time else self.calc_escalate_time(datetime.datetime.now())
        self.check_escalate()
        self.prev = None
        self.next = None


    #########
    #SETTERS#
    #########

    def set_name(self, new_name: str) -> None:
        self.name = new_name

    def set_category(self, new_category: str) -> None:
        self.category = new_category

    def set_description(self, new_description: str) -> None:
        self.description = new_description

    def set_escalate_time(self, new_escalate_time: datetime.datetime) -> None:
        self.escalate_time = new_escalate_time

    ############
    #ESCALATION#
    ############

    def escalate(self, force: bool = False):
        # Advances priority by 1 and recalculates escalate time
        # (force = False), unforced escalates occur naturally and recalculates escalate time based on existing escalate time
        # (force = True), force escalates occur when user requests an escalation and recalculates escalate time from now

        if self.priority == 0:
            return None
        
        self.priority -= 1
        self.escalate_time = self.calc_escalate_time(datetime.datetime.now() if force else self.escalate_time)
        return self

    def deescalate(self):
        # Downgrades priority by 1 and recalculates escalate time
        # Occurs onlw when user requests a de-escalation

        if self.priority == 4:
            return None
        
        self.priority += 1
        self.escalate_time = self.calc_escalate_time(datetime.datetime.now())
        return self

    def check_escalate(self):
        # Checks that an escalation needs to happen and escalates
        while self.escalate_time and datetime.datetime.now() > self.escalate_time:
            self.escalate()
    
    def calc_escalate_time(self, from_time: datetime.datetime) -> datetime.datetime:
        # Calculates a new escalation time relative to a give datetime
        if self.priority == 0:
            return None
        
        more_days = datetime.timedelta(days = DAYS_TO_ESCALATE[self.priority])
        return datetime.datetime(from_time.year, from_time.month, from_time.day) + more_days

    #########
    #DISPLAY#
    #########

    def get_basic_info(self) -> List[str]:
        # Returns an array of readable strings of the Task's properties
        info = self.get_properties()
        info["priority"] = f"P{info['priority']}"
        info["escalate_time"] = f"{self.calc_days_til_escalate()} days" if self.escalate_time else None
        for attr in info:
            info[attr] = str(info[attr]) if info[attr] else ""

        return list(info.values())

    def calc_days_til_escalate(self) -> int:
        # Returns a readable 'days until escalation' int
        if self.escalate_time:
            return (self.escalate_time - datetime.datetime.now()).days + 1
         
    def get_properties(self) -> Dict:
        return {
            "local_id": self.local_id,
            "name": self.name,
            "time_created": self.time_created.strftime(TIME_FORMAT),
            "priority": self.priority,
            "category": self.category,
            "description": self.description,
            "escalate_time": self.escalate_time.strftime(TIME_FORMAT) if self.escalate_time else None,
        }

    def __str__(self) -> str:
        return json.dumps(self.get_properties())

    @staticmethod
    def get_readable_attribute_names():
        return ["Local Id", "Name", "Time Created", "Priority", "Category", "Description", "Escalate Time"]
    @staticmethod
    def get_attribute_names():
        return [attribute.lower().replace(" ", "_") for attribute in Task.get_readable_attribute_names()]

# For dummy header and tail nodes
class EmptyNode:
    def __init__(self):
        self.next = None
        self.prev = None

class TodoQueue:
    def __init__(self, infile: str = None):
        self.local_id_counter = 0
        self.ids = {}
        self.head, self.tail = EmptyNode(), EmptyNode()
        self.head.next, self.tail.prev = self.tail, self.head
        self.mobile = False

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
    
    def pull_given_id(self, local_id) -> Task:
        if task_to_remove := self.ids.get(local_id):
            return self.remove_task(task_to_remove)
    
    def get_given_id(self, local_id) -> Task:
        return self.ids.get(local_id)

    def get_top_k(self, k = 5):
        return self.output_table([task.get_basic_info() for task in self][:k])

    def output_table(self, output_tasks):
        output = [Task.get_readable_attribute_names()] + output_tasks
        if self.mobile:
            output[0][0], output[0][3] = "Id", "P"
            output = [[row[i] for i in (0, 1, 3)] for row in output]
        return table(output, centered=True) + "\n"
    
    def filter(self, filter_func, k = None):
        return [task.get_basic_info() for task in self if filter_func(task)]

    def __str__(self):
        return self.output_table(self.filter(lambda x: True))

    def __iter__(self):
        self.curr_node = self.head
        return self
    
    def __next__(self):
        curr_task = self.curr_node.next
        if isinstance(curr_task, Task):
            self.curr_node = self.curr_node.next
            return curr_task
        raise StopIteration


    
