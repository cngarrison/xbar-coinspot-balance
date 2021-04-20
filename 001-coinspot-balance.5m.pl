#!/usr/bin/env perl

# <xbar.title>Coinspot Balance</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Charlie Garrison</xbar.author>
# <xbar.author.github>cngarrison</xbar.author.github>
# <xbar.desc>Display AUD balance and coin price from Coinspot.</xbar.desc>

# <xbar.var>boolean(VAR_TOTAL_IN_BAR=true): Whether to show wallet total in menubar.</xbar.var>
# <xbar.var>string(VAR_COINS_FONT="Menlo"): The font to use for showing coin prices - monospaced fonts work best.</xbar.var>
# <xbar.var>string(VAR_FAV_COINS="[["BTC","₿"]]"): JSON arry of fav coins - Each array element should be two-item array of coin name & currency symbol - eg [["BTC","₿"],["DOGE","Ð"]].</xbar.var>
# <xbar.var>string(VAR_CS_API_KEY=""): Coinspot read-only API key - or leave blank to get value from keychain - add to keychain with `security add-generic-password -a $USER -c "cnsp" -C "cspk" -s "coinspot read-only api key" -l "Coinspot key" -w`.</xbar.var>
# <xbar.var>string(VAR_CS_API_SECRET=""): Coinspot read-only API secret - or leave blank to get value from keychain - add to keychain with `security add-generic-password -a $USER -c "cnsp" -C "csps" -s "coinspot read-only api secret" -l "Coinspot secret" -w`.</xbar.var>

use strict;
use warnings;
use v5.18;
use utf8;
use open qw/:std :utf8/;
# binmode(STDOUT, ":utf8");
# use Sys::Binmode;

use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);
use Digest::SHA qw(hmac_sha512_hex);
use Data::Printer;
use List::Util qw(sum);
use Number::Format;

#$ENV{MOJO_CLIENT_DEBUG} = 1;


my $darkmode = (exists $ENV{XBARDarkMode} && $ENV{XBARDarkMode} eq 'true') ? 1 : 0;

my $coinspot_logo_dark =
  'iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAACXBIWXMAABYlAAAWJQFJUiTwAAAHi2lUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNi4wLWMwMDYgNzkuMTY0NzUzLCAyMDIxLzAyLzE1LTExOjUyOjEzICAgICAgICAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RFdnQ9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZUV2ZW50IyIgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIiBwaG90b3Nob3A6Q29sb3JNb2RlPSIzIiBwaG90b3Nob3A6SUNDUHJvZmlsZT0ic1JHQiBJRUM2MTk2Ni0yLjEiIHhtcDpNb2RpZnlEYXRlPSIyMDIxLTA0LTE0VDEyOjQ2OjQxKzEwOjAwIiB4bXA6TWV0YWRhdGFEYXRlPSIyMDIxLTA0LTE0VDEyOjQ2OjQxKzEwOjAwIiB4bXA6Q3JlYXRlRGF0ZT0iMjAyMS0wNC0xNFQxMTo1Mjo0NSsxMDowMCIgZGM6Zm9ybWF0PSJpbWFnZS9wbmciIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6YzA1NmQ0ODAtNGJkZC00NDMxLTliYTktOWU2NDlmMWNiNmYxIiB4bXBNTTpEb2N1bWVudElEPSJhZG9iZTpkb2NpZDpwaG90b3Nob3A6MWE0OGNjY2YtOWYzNy1jNTQ5LThmNzAtNjgxMjMzNzAwNGNkIiB4bXBNTTpPcmlnaW5hbERvY3VtZW50SUQ9InhtcC5kaWQ6OWU0MzU1YTAtZmRkMS00NDU2LWFkZDAtNmIwOGQ5YzY4NDM2IiB0aWZmOkltYWdlV2lkdGg9IjUwNCIgdGlmZjpJbWFnZUxlbmd0aD0iNTA0IiB0aWZmOlJlc29sdXRpb25Vbml0PSIyIiBleGlmOkNvbG9yU3BhY2U9IjEiIGV4aWY6UGl4ZWxYRGltZW5zaW9uPSI1MDQiIGV4aWY6UGl4ZWxZRGltZW5zaW9uPSI1MDQiPiA8ZGM6dGl0bGU+IDxyZGY6QWx0PiA8cmRmOmxpIHhtbDpsYW5nPSJ4LWRlZmF1bHQiPmNvaW5zcG90PC9yZGY6bGk+IDwvcmRmOkFsdD4gPC9kYzp0aXRsZT4gPHhtcE1NOkhpc3Rvcnk+IDxyZGY6U2VxPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0icHJvZHVjZWQiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFmZmluaXR5IERlc2lnbmVyIDEuOS4zIiBzdEV2dDp3aGVuPSIyMDIxLTA0LTE0VDEyOjEwOjM3KzEwOjAwIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDo5ZTQzNTVhMC1mZGQxLTQ0NTYtYWRkMC02YjA4ZDljNjg0MzYiIHN0RXZ0OndoZW49IjIwMjEtMDQtMTRUMTI6NDY6NDErMTA6MDAiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMi4zIChNYWNpbnRvc2gpIiBzdEV2dDpjaGFuZ2VkPSIvIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDpjMDU2ZDQ4MC00YmRkLTQ0MzEtOWJhOS05ZTY0OWYxY2I2ZjEiIHN0RXZ0OndoZW49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';

my $coinspot_logo_light =
  'iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAACXBIWXMAABYlAAAWJQFJUiTwAAAHi2lUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNi4wLWMwMDYgNzkuMTY0NzUzLCAyMDIxLzAyLzE1LTExOjUyOjEzICAgICAgICAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RFdnQ9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZUV2ZW50IyIgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIiBwaG90b3Nob3A6Q29sb3JNb2RlPSIzIiBwaG90b3Nob3A6SUNDUHJvZmlsZT0ic1JHQiBJRUM2MTk2Ni0yLjEiIHhtcDpNb2RpZnlEYXRlPSIyMDIxLTA0LTE0VDEyOjQ2OjAxKzEwOjAwIiB4bXA6TWV0YWRhdGFEYXRlPSIyMDIxLTA0LTE0VDEyOjQ2OjAxKzEwOjAwIiB4bXA6Q3JlYXRlRGF0ZT0iMjAyMS0wNC0xNFQxMjoxMTo0OCsxMDowMCIgZGM6Zm9ybWF0PSJpbWFnZS9wbmciIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6Yzk4MTc5NGMtZGIwYS00YmI3LThhYWYtZmQxNWZmZGE4MmIyIiB4bXBNTTpEb2N1bWVudElEPSJhZG9iZTpkb2NpZDpwaG90b3Nob3A6MmU0YTNmOTMtYmY2Mi1lMDQyLWJiMzMtZmFmNGIwZmRhNWZlIiB4bXBNTTpPcmlnaW5hbERvY3VtZW50SUQ9InhtcC5kaWQ6NTNiMWVlMzItMzFmNi00NjUzLTgxYWQtNzRhMzdiMzVmYmIyIiB0aWZmOkltYWdlV2lkdGg9IjUwNCIgdGlmZjpJbWFnZUxlbmd0aD0iNTA0IiB0aWZmOlJlc29sdXRpb25Vbml0PSIyIiBleGlmOkNvbG9yU3BhY2U9IjEiIGV4aWY6UGl4ZWxYRGltZW5zaW9uPSI1MDQiIGV4aWY6UGl4ZWxZRGltZW5zaW9uPSI1MDQiPiA8ZGM6dGl0bGU+IDxyZGY6QWx0PiA8cmRmOmxpIHhtbDpsYW5nPSJ4LWRlZmF1bHQiPmNvaW5zcG90PC9yZGY6bGk+IDwvcmRmOkFsdD4gPC9kYzp0aXRsZT4gPHhtcE1NOkhpc3Rvcnk+IDxyZGY6U2VxPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0icHJvZHVjZWQiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFmZmluaXR5IERlc2lnbmVyIDEuOS4zIiBzdEV2dDp3aGVuPSIyMDIxLTA0LTE0VDEyOjExOjQ4KzEwOjAwIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDo1M2IxZWUzMi0zMWY2LTQ2NTMtODFhZC03NGEzN2IzNWZiYjIiIHN0RXZ0OndoZW49IjIwMjEtMDQtMTRUMTI6NDY6MDErMTA6MDAiIHN0RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMi4zIChNYWNpbnRvc2gpIiBzdEV2dDpjaGFuZ2VkPSIvIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1wLmlpZDpjOTgxNzk0Yy1kYjBhLTRiYjctOGFhZi1mZDE1ZmZkYTgyYjIiIHN0RXZ0OndoZW49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';

my $wallet_icon_dark =
  'iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAACXBIWXMAABYlAAAWJQFJUiTwAAAHMGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNi4wLWMwMDYgNzkuMTY0NzUzLCAyMDIxLzAyLzE1LTExOjUyOjEzICAgICAgICAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0RXZ0PSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VFdmVudCMiIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyIgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIiBwaG90b3Nob3A6Q29sb3JNb2RlPSIzIiBwaG90b3Nob3A6SUNDUHJvZmlsZT0ic1JHQiBJRUM2MTk2Ni0yLjEiIHhtcDpNb2RpZnlEYXRlPSIyMDIxLTA0LTE0VDEzOjMzOjE5KzEwOjAwIiB4bXA6TWV0YWRhdGFEYXRlPSIyMDIxLTA0LTE0VDEzOjMzOjE5KzEwOjAwIiB4bXA6Q3JlYXRlRGF0ZT0iMjAyMS0wNC0xNFQxMzozMjowMysxMDowMCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo1N2ExMmM1ZC1iNTRkLTQwZWQtOGE1Zi05YjdhODkxYjBlN2YiIHhtcE1NOkRvY3VtZW50SUQ9ImFkb2JlOmRvY2lkOnBob3Rvc2hvcDo3YmIxNDQzMC1lNWNlLThjNDYtODMyNy1iYjAyNTk3NzUyZjciIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRpZDo4MjVjMjYyZC1jZDk1LTRiMDUtYjM2Zi0zMTIwYWY2MWY2ZWIiIHRpZmY6SW1hZ2VXaWR0aD0iNTEyIiB0aWZmOkltYWdlTGVuZ3RoPSI1MTIiIHRpZmY6UmVzb2x1dGlvblVuaXQ9IjIiIGV4aWY6Q29sb3JTcGFjZT0iMSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjUxMiIgZXhpZjpQaXhlbFlEaW1lbnNpb249IjUxMiIgZGM6Zm9ybWF0PSJpbWFnZS9wbmciPiA8eG1wTU06SGlzdG9yeT4gPHJkZjpTZXE+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJwcm9kdWNlZCIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWZmaW5pdHkgRGVzaWduZXIgMS45LjMiIHN0RXZ0OndoZW49IjIwMjEtMDQtMTRUMTM6MzI6MDMrMTA6MDAiLz4gPHJkZjpsaSBzdEV2dDphY3Rpb249InNhdmVkIiBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOjgyNWMyNjJkLWNkOTUtNGIwNS1iMzZmLTMxMjBhZjYxZjZlYiIgc3RFdnQ6d2hlbj0iMjAyMS0wNC0xNFQxMzozMzoxOSsxMDowMCIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWRvYmUgUGhvdG9zaG9wIDIyLjMgKE1hY2ludG9zaCkiIHN0RXZ0OmNoYW5nZWQ9Ii8iLz4gPHJkZjpsaSBzdEV2dDphY3Rpb249InNhdmVkIiBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOjU3YTEyYzVkLWI1NGQtNDBlZC04YTVmLTliN2E4OTFiMGU3ZiIgc3RFdnQ6d2hlbj0iMjAyMS0wNC0xNFQxMzozMzoxOSsxMDowMCIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWRvYmUgUGhvdG9zaG9wIDIyLjMgKE1hY2ludG9zaCkiIHN0RXZ0OmNoYW5nZWQ9Ii8iLz4gPC9yZGY6U2VxPiA8L3htcE1NOkhpc3Rvcnk+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+fR0qLgAAAZdJREFUWIXt2L9qFVEQx/HPWS9ELkYIKlaiICkUbEQbSwsFFSzTpM9z+AIWqQKChY3Y+gTaiCCCf7DQgEQ0pLK4V0yCosfi7OJ6QdbCPXuK+6uW3YH5MjN75syEGKOSVA0NMKtR6/kEzmAJAT979FshYgdP8a35EOqUXcSV+t1+DRN6BIo4gEVs4QF2SRE6jev4XMP0CTKrCU5JAXncAJ2vQfZro4BD8tRXxIJULhqgMb76HZkRPkh57TtaAZ/wog10DO+kqCxJRfa8Z5C/KsQYN/EQ73EUb/AIP3L4r/1M2kDNydgU9AK+ZwbaxDruhhjjBIczOP8XrYUY41Q6D0rQtLTWMS4NaK80oPK6/RyoS8UBjbpN/qv2cE9q3jdwaWigDdyXmvgz3Ma5tkHOlEW8xkksS73z7axRTqCAy/iIlziOC7NGuVO2iiPSVeeadH39Q6U11y/F/fZzoC5V8s5hnapwcGiIlkIlzUWlaFzh1tAULW03y4YNrA0MA1dDa2G1gps4K43XOeayEaZ4hTt4EuYbtA79AlXoYrpx5mB7AAAAAElFTkSuQmCC';

my $wallet_icon_light =
  'iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAACXBIWXMAABYlAAAWJQFJUiTwAAAHMGlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSLvu78iIGlkPSJXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQiPz4gPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iQWRvYmUgWE1QIENvcmUgNi4wLWMwMDYgNzkuMTY0NzUzLCAyMDIxLzAyLzE1LTExOjUyOjEzICAgICAgICAiPiA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpwaG90b3Nob3A9Imh0dHA6Ly9ucy5hZG9iZS5jb20vcGhvdG9zaG9wLzEuMC8iIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIgeG1sbnM6eG1wTU09Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9tbS8iIHhtbG5zOnN0RXZ0PSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VFdmVudCMiIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIiB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyIgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIiBwaG90b3Nob3A6Q29sb3JNb2RlPSIzIiBwaG90b3Nob3A6SUNDUHJvZmlsZT0ic1JHQiBJRUM2MTk2Ni0yLjEiIHhtcDpNb2RpZnlEYXRlPSIyMDIxLTA0LTE0VDEzOjMyOjQ5KzEwOjAwIiB4bXA6TWV0YWRhdGFEYXRlPSIyMDIxLTA0LTE0VDEzOjMyOjQ5KzEwOjAwIiB4bXA6Q3JlYXRlRGF0ZT0iMjAyMS0wNC0xNFQxMzozMToyOCsxMDowMCIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDoyNzI0YmE0NS0zMzY2LTQ5M2YtYTk5OC1hZGU1YmRjMWE2MTgiIHhtcE1NOkRvY3VtZW50SUQ9ImFkb2JlOmRvY2lkOnBob3Rvc2hvcDpkYzU3ZjQ1My02MzFlLTZlNGUtYjdjOS02NjAwZDEwMzYyZjAiIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0ieG1wLmRpZDpjZTRmZGFjZi1mY2Q5LTRiZWEtYjRmYi00NTVhNGU2Yjc3YTgiIHRpZmY6SW1hZ2VXaWR0aD0iNTEyIiB0aWZmOkltYWdlTGVuZ3RoPSI1MTIiIHRpZmY6UmVzb2x1dGlvblVuaXQ9IjIiIGV4aWY6Q29sb3JTcGFjZT0iMSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjUxMiIgZXhpZjpQaXhlbFlEaW1lbnNpb249IjUxMiIgZGM6Zm9ybWF0PSJpbWFnZS9wbmciPiA8eG1wTU06SGlzdG9yeT4gPHJkZjpTZXE+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJwcm9kdWNlZCIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWZmaW5pdHkgRGVzaWduZXIgMS45LjMiIHN0RXZ0OndoZW49IjIwMjEtMDQtMTRUMTM6MzE6MjgrMTA6MDAiLz4gPHJkZjpsaSBzdEV2dDphY3Rpb249InNhdmVkIiBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOmNlNGZkYWNmLWZjZDktNGJlYS1iNGZiLTQ1NWE0ZTZiNzdhOCIgc3RFdnQ6d2hlbj0iMjAyMS0wNC0xNFQxMzozMjo0OSsxMDowMCIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWRvYmUgUGhvdG9zaG9wIDIyLjMgKE1hY2ludG9zaCkiIHN0RXZ0OmNoYW5nZWQ9Ii8iLz4gPHJkZjpsaSBzdEV2dDphY3Rpb249InNhdmVkIiBzdEV2dDppbnN0YW5jZUlEPSJ4bXAuaWlkOjI3MjRiYTQ1LTMzNjYtNDkzZi1hOTk4LWFkZTViZGMxYTYxOCIgc3RFdnQ6d2hlbj0iMjAyMS0wNC0xNFQxMzozMjo0OSsxMDowMCIgc3RFdnQ6c29mdHdhcmVBZ2VudD0iQWRvYmUgUGhvdG9zaG9wIDIyLjMgKE1hY2ludG9zaCkiIHN0RXZ0OmNoYW5nZWQ9Ii8iLz4gPC9yZGY6U2VxPiA8L3htcE1NOkhpc3Rvcnk+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+f50Y+AAAAYhJREFUWIXt2D1rFUEUgOFn9l4/cxUiigiKQdPYGkmTIpUoKMFGbC38KfaClvkBwcrCHyBCGhsxEKJCPhA7FYIRiVFu1mJnYVkCt7qzU9wXFpbDWeZldw7n7ISyLOVE0bVAm9C4v4QbGOAQ43x1Rby+4x2GbaGbuBuTDsYo0iRgCtt4iT/QxwzuYzcGw9HPj4VdXMctrNZCc/hXG0ahgTT7q8QJXK4DfZzEfhQJMbYdJcdNwBe8bwpNx+AA5/AWHxLIHEnAJ7zCFi5iDW9UlZaCIf42hery/okeTuG3RikmENrBM6yEKHI20eKjeBywhzNdm0S+5dY6pnMTOshNqMxNKL/xYyI0in7i9fawjK+4h9tdCh3iBV7jAp6qmvlcMynlJxuqGvk1XFX10M/tpJRCx7ComrXWVWPPfDsp9R56gvOqUWcJs+2E3Jrrr+zKfiI0ikI1tmZD/UubC0WBza4tGhzv4Qcedm0S2exhA6ex0LEMPGgeLNzBI1yRvsdt4Tk+hskJ2gj+A3EGSfWCvqE2AAAAAElFTkSuQmCC';

my $icon   = $darkmode ? $coinspot_logo_dark : $coinspot_logo_light;
my $wallet = $darkmode ? $wallet_icon_dark   : $wallet_icon_light;


## Run these command in Terminal to add key/secret to keychain
# security add-generic-password -a $USER -c "cnsp" -C "cspk" -s "coinspot read-only api key" -l "Coinspot key" -w
# security add-generic-password -a $USER -c "cnsp" -C "csps" -s "coinspot read-only api secret" -l "Coinspot secret" -w

my $kc_key    = qx/security find-generic-password -s "coinspot read-only api key" -l "Coinspot key" -w/;
my $kc_secret = qx/security find-generic-password -s "coinspot read-only api secret" -l "Coinspot secret" -w/;

my $api_key    = $ENV{VAR_CS_API_KEY}    || $kc_key    || '';
my $api_secret = $ENV{VAR_CS_API_SECRET} || $kc_secret || '';

if ( !$api_key || !$api_secret ) {
	say "No API key/secret | templateImage=$icon trim=false";
	exit 1;
}

chomp $api_key;
chomp $api_secret;

my $total_in_bar = (exists $ENV{VAR_TOTAL_IN_BAR} && $ENV{VAR_TOTAL_IN_BAR} eq 'true') ? 1 : 0;
#say np($total_in_bar);

my $coins_font = $ENV{VAR_COINS_FONT} || 'Menlo';

## I'd like to move these to xbar.var definition, but it doesn't appear to support arrays
my @fav_coins =
  $ENV{VAR_FAV_COINS}
  ? @{ decode_json( $ENV{VAR_FAV_COINS} ) }
  : (
	['HBAR', 'ℏ'],
	['BTC',  '₿'],
	['DOGE', 'Ð'],
  );
#say np(@fav_coins);

my $nonce   = int( time * 1000000 );
my $payload = "{\"nonce\":$nonce}";

my $signed = hmac_sha512_hex( $payload, $api_secret );

my $headers = {
	'Content-Type' => 'application/json;charset=utf-8',
	'charset'      => 'UTF-8',
	'Accept'       => 'application/json',
	'key'          => $api_key,
	'sign'         => $signed,
};

my $ua = Mojo::UserAgent->new;
my $nf = Number::Format->new( -int_curr_symbol => '' ); # put $ sign directly into sprintf since Number::Format puts space between symbol and number

my $res      = $ua->post( 'https://www.coinspot.com.au/api/ro/my/balances' => $headers => $payload )->result->json;
my $balances = $res->{balances};
# say np($balances);

my @audbals = map {
	my $curr = ( keys %$_ )[0];
	$_->{$curr}->{audbalance};
} @$balances;
#say np(@audbals);

say( ( $total_in_bar ? ' $' . $nf->format_price( sum(@audbals), 2 ) : '' ) . "| templateImage=$icon trim=false" );
say "---";
say "CoinSpot Wallet Total| size=10";
say sprintf(
	'  $%s| size=18 href="https://www.coinspot.com.au/my/dashboard" trim=false image=%s font="%s"',
	$nf->format_price( sum(@audbals), 2 ),
	$wallet,
	$coins_font,
);
say "---";
say "Favourites| size=10";
foreach my $fav (@fav_coins) {
	my ($fav_coin) = grep { ( keys %$_ )[0] eq $fav->[0] } @$balances;
	say sprintf(
		'%s	$%-10s 	(%s)|size=16 href="https://www.coinspot.com.au/my/wallet/%s/dashboard" terminal=false trim=false font="%s"',
		$fav->[1],
		$nf->format_price( $fav_coin->{ $fav->[0] }->{audbalance}, 2 ),
		$nf->format_number( $fav_coin->{ $fav->[0] }->{rate}, 3 ),
		lc $fav->[0],
		$coins_font,
	);
	#say "---";
} ## end foreach my $fav (@fav_coins)

say "---";
say 'All Coins| size=12';
foreach my $bal (
	sort {
		my $curr_a = ( keys %$a )[0];
		my $curr_b = ( keys %$b )[0];
		$b->{$curr_b}->{audbalance} <=> $a->{$curr_a}->{audbalance}
	} @$balances
) {
	my $curr = ( keys %$bal )[0];
	my $aud  = $bal->{$curr}->{audbalance};
	my $rate = $bal->{$curr}->{rate};
	say sprintf(
		'-- %-2s	 $%-10s 	(%s)|size=14 href="https://www.coinspot.com.au/my/wallet/\%s/dashboard" terminal=false trim=false font="%s"',
		$curr,
		$nf->format_price( $aud, 2 ),
		$nf->format_number( $rate, 4 ),
		lc $curr,
		$coins_font,
	);
} ## end foreach my $bal ( sort { my $curr_a =...})

say "---";
say 'Update| size=12 refresh=true';

exit;


1;
