import Foundation
import Testing
@testable import SayCal

struct RegexScheduleParserTests {

    // 2026-05-14는 목요일
    private static func referenceNow() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 14
        components.hour = 10
        components.minute = 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar.date(from: components)!
    }

    // MARK: - 날짜: 상대 키워드

    @Test func todayResolvesToReferenceDate() {
        let result = RegexScheduleParser.extractDate("오늘 약속", now: Self.referenceNow())
        #expect(result == "2026-05-14")
    }

    @Test func tomorrowAddsOneDay() {
        let result = RegexScheduleParser.extractDate("내일 회의", now: Self.referenceNow())
        #expect(result == "2026-05-15")
    }

    @Test func dayAfterTomorrowAddsTwoDays() {
        let result = RegexScheduleParser.extractDate("모레 점심", now: Self.referenceNow())
        #expect(result == "2026-05-16")
    }

    @Test func threeDaysLaterAddsThreeDays() {
        let result = RegexScheduleParser.extractDate("글피 출장", now: Self.referenceNow())
        #expect(result == "2026-05-17")
    }

    // MARK: - 날짜: 주간 요일

    @Test func thisWeekSaturday() {
        // 목요일 기준 이번주 토요일 = +2일
        let result = RegexScheduleParser.extractDate("이번주 토요일 약속", now: Self.referenceNow())
        #expect(result == "2026-05-16")
    }

    @Test func thisWeekMondayIsPast() {
        // 목요일 기준 이번주 월요일 = -3일 (지난 월요일)
        let result = RegexScheduleParser.extractDate("이번주 월요일 약속", now: Self.referenceNow())
        #expect(result == "2026-05-11")
    }

    @Test func nextWeekMonday() {
        let result = RegexScheduleParser.extractDate("다음주 월요일 회의", now: Self.referenceNow())
        #expect(result == "2026-05-18")
    }

    @Test func nextWeekFriday() {
        let result = RegexScheduleParser.extractDate("다음주 금요일 회식", now: Self.referenceNow())
        #expect(result == "2026-05-22")
    }

    @Test func bareWeekdayRollsForwardWhenPast() {
        // 목요일 기준 "수요일" = 어제지만, 명시적 이번주 없으면 다음주 수요일로
        let result = RegexScheduleParser.extractDate("수요일 약속", now: Self.referenceNow())
        #expect(result == "2026-05-20")
    }

    @Test func bareWeekdayTodayReturnsToday() {
        // 목요일 기준 "목요일" = 오늘
        let result = RegexScheduleParser.extractDate("목요일 회의", now: Self.referenceNow())
        #expect(result == "2026-05-14")
    }

    // MARK: - 날짜: N월 N일

    @Test func absoluteMonthDayThisYear() {
        let result = RegexScheduleParser.extractDate("6월 15일 워크숍", now: Self.referenceNow())
        #expect(result == "2026-06-15")
    }

    @Test func absoluteMonthDayPastRollsToNextYear() {
        // 5월 14일 기준 3월 15일은 이미 지났음 → 내년
        let result = RegexScheduleParser.extractDate("3월 15일 행사", now: Self.referenceNow())
        #expect(result == "2027-03-15")
    }

    // MARK: - 시간

    @Test func morningTimeWithMinutes() {
        #expect(RegexScheduleParser.extractTime("오전 9시 30분") == "09:30")
    }

    @Test func morningTimeWithoutMinutes() {
        #expect(RegexScheduleParser.extractTime("오전 7시") == "07:00")
    }

    @Test func afternoonTimeConvertsTo24h() {
        #expect(RegexScheduleParser.extractTime("오후 3시") == "15:00")
    }

    @Test func afternoonTwelveStaysTwelve() {
        #expect(RegexScheduleParser.extractTime("오후 12시") == "12:00")
    }

    @Test func morningTwelveBecomesMidnight() {
        #expect(RegexScheduleParser.extractTime("오전 12시") == "00:00")
    }

    @Test func bareHourMinute() {
        #expect(RegexScheduleParser.extractTime("14시 30분 회의") == "14:30")
    }

    @Test func colonNotation() {
        #expect(RegexScheduleParser.extractTime("회의 15:45") == "15:45")
    }

    @Test func noonKeyword() {
        #expect(RegexScheduleParser.extractTime("정오 약속") == "12:00")
    }

    @Test func midnightKeyword() {
        #expect(RegexScheduleParser.extractTime("자정 마감") == "00:00")
    }

    // MARK: - 통합 케이스

    @Test func combinedDateAndTime() {
        let result = RegexScheduleParser.parse("이번주 토요일 오후 3시 강남역", now: Self.referenceNow())
        #expect(result.date == "2026-05-16")
        #expect(result.time == "15:00")
    }

    @Test func emptyStringReturnsEmpty() {
        let result = RegexScheduleParser.parse("회의", now: Self.referenceNow())
        #expect(result.date == "")
        #expect(result.time == "")
    }
}
