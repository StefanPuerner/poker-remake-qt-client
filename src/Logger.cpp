#include "../include/Logger.hpp"

#include <chrono>
#include <ctime>
#include <iostream>

#include "../include/TimeUtils.hpp"

Logger& Logger::instance() {
  static Logger inst;
  return inst;
}

void Logger::open(const std::string& dir) {
  auto now  = std::chrono::system_clock::now();
  std::time_t t = std::chrono::system_clock::to_time_t(now);
  struct tm tm_buf {};
  localtimePortable(&t, &tm_buf);

  char stamp[20];
  std::strftime(stamp, sizeof(stamp), "%Y%m%d_%H%M%S", &tm_buf);

  std::string path = dir + "server_" + stamp + ".log";

  std::lock_guard<std::mutex> lk(mutex_);
  file_.open(path, std::ios::out | std::ios::app);
  if (!file_.is_open())
    std::cerr << "[Logger] No se pudo abrir: " << path << "\n";
  else
    file_ << "=== PokerServer log " << stamp << " ===\n";
}

void Logger::close() {
  std::lock_guard<std::mutex> lk(mutex_);
  if (file_.is_open()) file_.close();
}

void Logger::log(Level lvl, const std::string& msg) {
  auto now = std::chrono::system_clock::now();
  std::time_t t = std::chrono::system_clock::to_time_t(now);
  struct tm tm_buf {};
  localtimePortable(&t, &tm_buf);

  char ts[20];
  std::strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", &tm_buf);

  const char* tag = (lvl == Level::INFO)  ? "[INFO] "
                  : (lvl == Level::WARN)  ? "[WARN] "
                                           : "[ERROR]";

  std::string line = std::string(ts) + " " + tag + " " + msg;

  std::lock_guard<std::mutex> lk(mutex_);
  if (file_.is_open()) {
    file_ << line << "\n";
    file_.flush();
  }
  std::cerr << line << "\n";
}
