import EventKit
import Foundation

class EventManager: NSObject {
    
    let eventStore = EKEventStore()
    
    override init() {
        super.init()
    }
    
    func loadReminders(result: @escaping FlutterResult) {
        eventStore.requestAccess(to: .reminder) { (granted, error) in
            if granted {
                let predicate = self.eventStore.predicateForReminders(in: nil)
                self.eventStore.fetchReminders(matching: predicate) { reminders in
                    var reminderList = [[String: Any]]()
                    for reminder in reminders ?? [] {
                        let title = reminder.title ?? ""
                        let notes = reminder.notes ?? ""
                        let completed = reminder.isCompleted
                        if (!completed) {
                            reminderList.append([
                                "title": title,
                                "notes": notes,
                                "completed": completed
                            ])
                        }
                    }
                    result(reminderList)
                }
            } else {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Access to reminders denied", details: nil))
            }
        }
    }
    
    func loadUpcomingEvents(result: @escaping FlutterResult) {
        eventStore.requestAccess(to: .event) { (granted, error) in
            if granted {
                let startDate = Date()
                let endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate)!
                let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
                
                let events = self.eventStore.events(matching: predicate)
                var eventList = [[String: Any]]()
                
                for event in events {
                    let title = event.title ?? ""
                    let startDate = event.startDate ?? Date()
                    let endDate = event.endDate ?? Date()
                    let location = event.location ?? ""
                    eventList.append([
                        "title": title,
                        "startDate": startDate.description,
                        "endDate": endDate.description,
                        "location": location
                    ])
                }
                
                result(eventList)
            } else {
                result(FlutterError(code: "PERMISSION_DENIED", message: "Access to calendar events denied", details: nil))
            }
        }
    }
}
