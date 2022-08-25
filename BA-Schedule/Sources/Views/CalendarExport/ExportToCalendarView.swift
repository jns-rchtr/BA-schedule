//
//  ExportToCalendarView.swift
//  BA-Schedule
//
//  Created by Jonas Richard Richter on 22.08.22.
//

import SwiftUI
import EventKit
import Logging
import UIKit
import CampusDualKit

struct ExportToCalendarView: View {
    private var logger = Logger(for: "ExportToCalendarView")
    @Environment(\.presentationMode) var presentationMode
    
    private var ekStore = EKEventStore()
    
    @State private var showPermissionSheet = false
    @State private var showErrorSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Image(systemName: "calendar.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 62)
                    .foregroundColor(.accentColor)
                Text("Studenplan in den Kalendar exportieren")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button {
                    Task {
                       await exportToCalendar()
                    }
                } label: {
                    Text("Exportieren")
                        .bold()
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.borderedProminent)

            }
                .padding()
                .sheet(isPresented: $showPermissionSheet) {
                    GrantCalendarPermissionView()
                }
                .sheet(isPresented: $showErrorSheet, onDismiss: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    NoCalendarPermissionView()
                }
        }
        .onAppear {
            checkPermission()
        }
    }
    
    func checkPermission() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            showPermissionSheet = true
            break
        case .denied, .restricted:
            showErrorSheet = true
            break
        default:
            break
        }
    }
    
    func getBACalenderOrCreate() -> EKCalendar {
        let userCalenders = ekStore.calendars(for: .event)
        
        let baCalenders = userCalenders.filter { calender in
            return calender.title == "BA-Schedule"
        }
        
        if (baCalenders.count == 0) {
            let calendar = EKCalendar(for: .event, eventStore: ekStore)
            
            calendar.title = "BA-Schedule"
            calendar.cgColor = UIColor(Color.red).cgColor
            calendar.source = ekStore.defaultCalendarForNewEvents?.source!
            
            self.logger.info("Created calendar: \(calendar.debugDescription)")
            
            do {
                try ekStore.saveCalendar(calendar, commit: true)
                logger.info("Saved new calendar")
            } catch {
                logger.error("Error while saving new calendar: \(error.localizedDescription)")
#warning("Implement error dialog")
            }
            
            return calendar
        }
        
        return baCalenders.first!
    }
    
    func exportToCalendar() async {
        let calender = getBACalenderOrCreate()
        
        let service = ServiceWrapper()
        var schedule: [StudyDay] = []
        do {
            schedule = try await service.loadFromJson()
        } catch {
            logger.error("An error happend: \(error.localizedDescription)")
            #warning("implement error dialog")
        }
        
        for studyDay in schedule {
            for lesson in studyDay.lessons {
                let event = EKEvent(eventStore: ekStore)
                
                event.calendar = calender
                event.title = lesson.title
                event.location = lesson.room + " " + lesson.remarks
                event.startDate = lesson.start
                event.endDate = lesson.end
                event.availability = .busy
                
                do {
                    try ekStore.save(event, span: .thisEvent, commit: true)
                } catch {
                    logger.error("An error happend: \(error.localizedDescription)")
                    #warning("Implement error dialog")
                }
            }
        }
    }
}

struct ExportToCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        ExportToCalendarView()
    }
}