#include <cstring>
#include <string>
#include <vector>
#include <memory>
#include <iostream> // 로그 출력을 위해 추가
#include "kiwi/Kiwi.h"

static std::unique_ptr<kiwi::Kiwi> global_kiwi;

extern "C" {
    #ifdef _WIN32
    __declspec(dllexport)
    #else
    __attribute__((visibility("default")))
    #endif
    
    int init_kiwi(const char* model_path) {
        try {
            // [수정] 이미 초기화되어 있다면 '성공(1)'으로 간주하고 리턴
            if (global_kiwi) {
                std::cout << "[Native] Kiwi is already initialized." << std::endl;
                return 1; 
            }

            std::cout << "[Native] Loading Kiwi model from: " << model_path << std::endl;

            // 모델 로드 시도
            global_kiwi = std::make_unique<kiwi::Kiwi>(
                kiwi::KiwiBuilder(model_path, 1).build()
            );
            
            std::cout << "[Native] Kiwi loaded successfully!" << std::endl;
            return 1; // 성공

        } catch (const std::exception& e) {
            // [추가] 구체적인 에러 메시지 출력 (터미널에서 확인 가능)
            std::cerr << "[Native Error] Init failed: " << e.what() << std::endl;
            return -1; // 실패
        } catch (...) {
            std::cerr << "[Native Error] Unknown error occurred." << std::endl;
            return -1;
        }
    }

    #ifdef _WIN32
    __declspec(dllexport)
    #else
    __attribute__((visibility("default")))
    #endif
    void extract_keywords(const char* text, char* buffer, int buffer_size) {
        try {
            if (!global_kiwi) {
                strncpy(buffer, "ERROR_NOT_INIT", buffer_size - 1);
                return;
            }
            
            auto res = global_kiwi->analyze(text, kiwi::Match::all);
            std::string result = "";
            
            for (const auto& token : res.first) {
                // 일반명사(nng), 고유명사(nnp), 외국어(sl) 추출
                if (token.tag == kiwi::POSTag::nng || 
                    token.tag == kiwi::POSTag::nnp || 
                    token.tag == kiwi::POSTag::sl) {
                    
                    // 2글자 이상이거나 외국어인 경우
                    if (token.str.length() >= 2 || token.tag == kiwi::POSTag::sl) {
                        result += kiwi::utf16To8(token.str) + ",";
                    }
                }
            }
            
            strncpy(buffer, result.c_str(), buffer_size - 1);
            buffer[buffer_size - 1] = '\0';
        } catch (...) {
            buffer[0] = '\0';
        }
    }
}