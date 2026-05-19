import React from 'react';
import { AlertCircle } from 'lucide-react';

/**
 * Standard Medical Disclaimer for AmbyoAI.
 * Required for clinical-grade transparency.
 */
const MedicalDisclaimer = ({ className = "" }) => {
  return (
    <div className={`p-4 bg-amber-50 border border-amber-200 rounded-xl flex gap-3 text-amber-900 shadow-sm ${className}`}>
      <div className="shrink-0 text-amber-600 mt-0.5">
        <AlertCircle size={20} />
      </div>
      <div className="text-sm leading-relaxed font-medium">
        This app provides screening and support only. It does <strong>not</strong> diagnose lazy eye,
        prescribe glasses, determine patching treatment, or replace an eye doctor. If screening is
        abnormal, incomplete, or if a child has eye turning, white pupil, poor vision, eye pain,
        trauma, or parent concern, consult a pediatric ophthalmologist or qualified eye-care
        professional.
      </div>
    </div>
  );
};

export default MedicalDisclaimer;
